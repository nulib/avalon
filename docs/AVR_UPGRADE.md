# Turning an Avalon release into an AVR release

AVR (Avalon Video Reserves) is Northwestern's deployment of
[Avalon Media System](https://github.com/avalonmediasystem/avalon). This repo is
a fork, but it is not maintained as a divergent branch: it is **a linear stack of
patches applied on top of an upstream release tag**. Upgrading means replaying
that stack onto a newer tag.

That framing is the whole design. Everything below exists to keep the stack
small, ordered so that the fragile parts are isolated, and honest about which
commits are ours forever versus which are on their way upstream.

- Companion doc: [AVR_CUSTOMIZATIONS.md](AVR_CUSTOMIZATIONS.md) — what each
  customization does, why it exists, and the known gaps.
- Development setup: [AVR_DEVELOPMENT.md](AVR_DEVELOPMENT.md).

## Branches and remotes

| Ref | What it is |
| --- | --- |
| `upstream` | `git@github.com:avalonmediasystem/avalon.git` |
| `origin` | `git@github.com:nulib/avalon.git` |
| `v8.2`, `v8.3`, … | Upstream release tags. The base of the patch stack. |
| `nu/deploy/staging` | What is deployed to staging. Pushing here builds and deploys. |
| `nu/deploy/production` | What is deployed to production. |
| `nu/upgrade-<version>` | Working branch for an upgrade, before it is fast-forwarded onto a deploy branch. |

A push to `nu/deploy/<env>` builds the image and redeploys; a push to
`nu/build/<env>` builds and pushes the image without deploying. Anything else
runs the test suite. See [`.github/workflows/build.yml`](../.github/workflows/build.yml).

Make sure both remotes exist and are current:

```bash
git remote -v && git fetch upstream --tags && git fetch origin
```

## The shape of the stack

`git log --oneline v8.2..nu/deploy/staging` should read as five groups, bottom
to top. The order is deliberate: the further down a commit is, the more likely
it is to disappear on its own, and the less likely it is to conflict.

**1. Fixes on their way upstream.** Small, self-contained, each one PR-able on
its own. Seven of these are cherry-picks of
[avalonmediasystem/avalon#6925](https://github.com/avalonmediasystem/avalon/pull/6925),
taken verbatim so that `git rebase` recognises them by patch-id and drops them
automatically once that PR merges. Keep new fixes in this group, one per commit,
and PR them — every one that lands upstream is one less thing to carry.

**2. Infrastructure and build.** Terraform, GitHub Actions, the container
entrypoint. Almost entirely new files under paths upstream doesn't use, so
almost never conflicts.

**3. Runtime plumbing.** SSM-sourced settings, SQS/Shoryuken background jobs,
ActiveStorage configuration, `Gemfile.local`. Mostly new files plus a handful of
marked blocks in `config/`.

**4. Product customizations.** Auth, Canvas, CloudFront streaming, branding,
redirects. This is where real conflicts live, because these touch upstream
controllers, models, and views.

**5. Development environment and dependency locks.** `config/database.yml`,
`config/puma.rb`, the `Guardfile`, and `Gemfile.lock` — which is always last,
and always regenerated rather than merged.

## The upgrade

Say the new release is `v8.3`.

### 0. Read what changed upstream

```bash
git log --oneline v8.2..v8.3
git diff --stat v8.2..v8.3 -- Dockerfile .circleci config/ db/migrate
```

Three things specifically:

- **`Dockerfile`** — base image versions, build stages, bundler invocation. AVR's
  delta is two marked blocks; everything outside them must be upstream's,
  verbatim.
- **`.circleci/config.yml`** — service container versions (Fedora, Solr,
  ZooKeeper, Postgres) and the Ruby version. AVR's GitHub Actions test job has to
  track these; they are not interchangeable across Avalon majors.
- **`db/migrate/`** — new migrations to run, and whether any of them touch tables
  AVR also writes to.

### 1. Rebase

Turn on `rerere` first — it remembers how you resolved a conflict, which matters
because you will resolve some of these more than once.

```bash
git config rerere.enabled true

git checkout -b nu/upgrade-8.3 nu/deploy/staging
git rebase --onto v8.3 v8.2
```

`--onto v8.3 v8.2` replays exactly `v8.2..HEAD` — the patch stack — onto the new
tag. Commits whose changes already exist in `v8.3` are dropped automatically.

When it stops:

- **`Gemfile.lock`** — don't resolve it. `git checkout --theirs Gemfile.lock`
  (or take upstream's outright) and move on; step 3 regenerates it.
- **A group-1 fix** — check whether upstream fixed the same thing differently. If
  they did, `git rebase --skip` and confirm afterwards that their version is
  present.
- **Anything else** — resolve it, then reread the commit message. Every AVR
  commit says what it is for and what it deliberately does *not* do; that is
  usually enough to tell whether upstream's new code makes the customization
  redundant. If it does, drop the commit rather than merging it forward. That is
  how the stack stays small.

Expect trouble in roughly this order: `config/application.rb`,
`app/controllers/catalog_controller.rb`,
`app/controllers/master_files_controller.rb`,
`app/views/catalog/index.html.erb`, `app/services/security_service.rb`.

### 2. Re-apply the Dockerfile delta

If upstream changed the `Dockerfile`, don't merge — replace and re-apply:

```bash
git checkout v8.3 -- Dockerfile
```

then paste the two `---- AVR delta N of 2 ----` blocks back in:

1. **In the `bundle` stage**, after upstream's `COPY Gemfile.lock`: a
   `COPY Gemfile.local ./Gemfile.local`. Easy to think redundant, and it is
   not. Upstream copies only `Gemfile` and `Gemfile.lock` before
   `bundle install`; without `Gemfile.local`, upstream's
   `eval_gemfile 'Gemfile.local' if File.exist?` quietly does nothing, bundler
   resolves a Gemfile that never mentions AVR's gems, and the git-sourced ones
   are never checked out. `bundle install` still *succeeds*. The failure lands
   two stages later, in `assets`, where `COPY . .` finally brings
   `Gemfile.local` in and `bundle exec rake assets:precompile` dies with
   `omniauth-nusso ... is not yet checked out`.
2. **At the end of the `prod` stage**: writable `/var/run/puma`, `EXPOSE`,
   `CMD`, `HEALTHCHECK`.

Both are short on purpose. If you find yourself wanting to change something
outside them, that's a signal to write it down in AVR_CUSTOMIZATIONS.md and
say why.

Then bring the GitHub Actions test job's `services:` and `ruby-version` /
`node-version` in line with upstream's `.circleci/config.yml` and `Dockerfile`.

### 3. Regenerate the dependency locks

**Never hand-merge `Gemfile.lock`.** A merged lock is how this fork ended up
carrying ~200 gems at versions the release didn't pin, plus a `hashie` downgrade
forced by a gem nothing used.

```bash
git checkout v8.3 -- Gemfile Gemfile.lock package.json yarn.lock
bundle lock --add-checksums
yarn install
git add Gemfile.lock yarn.lock package.json
```

`git diff v8.3 -- Gemfile.lock` should be **purely additive**: AVR's gems from
`Gemfile.local` and their dependencies, and nothing else. Removed lines, or
changed versions of upstream gems, mean the lock was resolved from scratch
instead of extended — start over from upstream's copy.

`git diff v8.3 -- Gemfile package.json` should be **empty**. AVR keeps its gems
in `Gemfile.local`, which upstream's `Gemfile` already evals, so neither file
needs an AVR change. If a rebase leaves one dirty, that's drift to remove.

Also check `BUNDLED WITH` still matches upstream's, since the `Dockerfile`
installs exactly that bundler version.

### 4. Verify

```bash
# Structure: the delta should be small and legible.
git diff --stat v8.3 HEAD -- . ':(exclude)terraform' ':(exclude)Gemfile.lock'

# Nothing should have crept into these.
git diff v8.3 HEAD -- Gemfile package.json yarn.lock

# These three have a known, fixed AVR delta. Anything more has crept in:
#   app/views/layouts/avalon.html.erb            2 lines (the __northwestern partials)
#   app/assets/stylesheets/application.sass.scss 1 @import (northwestern, and it must stay last)
#   app/views/catalog/index.html.erb             1 line  (renders nu_home)
git diff v8.3 HEAD -- app/views/layouts app/assets/stylesheets/application.sass.scss \
  app/views/catalog/index.html.erb

# Nothing else under app/assets or app/components should differ from upstream at
# all -- AVR's stylesheets live in their own directory. Expect only additions:
git diff --stat v8.3 HEAD --diff-filter=M -- app/assets app/components

# The branding stylesheets are built by dart-sass, not Sprockets, so a bad
# selector or a missing @import fails here and nowhere else.
yarn build:css

# Boot, migrate, test.
bundle exec rails runner 'puts Rails.application.class.module_parent_name'
bundle exec rake db:migrate
bundle exec rspec spec
```

Then build the image. `prod` is what CI ships and what must pass:

```bash
docker build --target=prod -t avr:upgrade-check .
```

`--target=dev` is worth trying too, because that target is the one that silently
rotted last time — nothing exercises it, so AVR had carried a `dev` stage
copying `--from` two nonexistent build stages for at least a release. Be aware
that upstream's `download` stage (used only by `dev`) fetches chromedriver from
`chromedriver.storage.googleapis.com`, which Google retired in favour of Chrome
for Testing, so a failure there is upstream's and not something the rebase
introduced:

```bash
docker build --target=dev -t avr:upgrade-check-dev .
```

Smoke-test on staging, in this order — these are the paths that have broken on
past upgrades and that the test suite covers least well:

1. **Log in via Northwestern SSO.** Confirm your session's virtual groups
   include your current Canvas courses (`user_session[:virtual_groups]`).
2. **Log in via an LTI launch** from Canvas and from Ares.
3. **Play a video.** Then check the network log: the playlist request should be a
   redirect to the CloudFront host with `Signature` and `Key-Pair-Id` query
   params, and the segment requests should carry `CloudFront-*` cookies. A
   dropped cookie usually means the cookie domain is wrong — see
   `SecurityService#cookie_domain`.
4. **Open the structural metadata editor** on a section with derivatives.
5. **Hit a legacy URL** that has a `redirects` row.
6. **Run a batch ingest** and confirm a worker picks the job off SQS.
7. **Load the home page** and a faceted search.
8. **View source** and confirm the GTM container snippet is present.
9. **Check the branding**, which is CSS coupled to upstream's markup and so is
   the thing an upgrade breaks most quietly. The purple Northwestern header and
   the four-column footer on a wide window; the purple navbar with the wordmark
   under 1140px, where the desktop header is hidden by design; the home page
   hero over the splash image; and the share dialog on a media object, which
   must **not** offer an IIIF manifest link. See "Known gaps" in
   `AVR_CUSTOMIZATIONS.md` for the selectors most likely to have rotted.

### 5. Ship

```bash
git push origin nu/upgrade-8.3          # runs the test suite
git push origin nu/upgrade-8.3:nu/deploy/staging
# ...verify staging...
git push origin nu/upgrade-8.3:nu/deploy/production
```

Terraform is deployed separately, from `terraform/`. If the release adds
settings AVR needs, add SSM parameters in `terraform/settings.tf` — deployed AVR
reads its configuration from Parameter Store, not from `config/settings/*.yml`.

### 6. Tidy the stack

Immediately after an upgrade, while it is all still in your head:

- Confirm that group-1 commits which landed upstream really did drop, and delete
  any local duplicates.
- Open PRs for group-1 fixes that aren't upstream yet.
- Update AVR_CUSTOMIZATIONS.md for anything added, dropped, or newly redundant.

## Keeping the stack small

Some habits that make the next upgrade cheaper, roughly in order of payoff:

**Prefer a file upstream doesn't have.** New file: zero conflicts, forever. In
descending order of preference:

1. A new file (`app/services/canvas_service.rb`, `config/locales/nu_avr.en.yml`).
2. Overriding a partial upstream already renders — `_google_analytics.html.erb`
   replaces upstream's analytics snippet without touching either layout.
3. Extracting AVR content into a partial and leaving a one-line `render` behind —
   `catalog/index.html.erb`.
4. Configuration over code. A label change belongs in a locale file; a service
   choice belongs in Settings. Editing a controller to change a string is the
   most expensive way to do it.
5. Editing upstream code, with an `# AVR:` comment saying why.

**Guard, don't comment out.** An early `return unless …` at the top of a block
leaves upstream's code byte-identical, so it keeps merging cleanly and you can
still see what you're skipping. `config/initializers/sidekiq.rb` does this.
Commenting a block out line by line guarantees a conflict on every release, and
this fork had two such blocks that had lost their closing `end` to a stray `#`.

**Never reformat upstream code.** A whitespace-only reindent of
`config/initializers/devise.rb` turned a one-line change into a 696-line diff,
and hid the fact that it had also dropped upstream's
`Rails.application.reloader.to_prepare` wrapper. Whitespace churn is where
regressions hide.

**Write the commit message for the person doing the next rebase.** Not what
changed — the diff says that — but *why it exists* and *what it deliberately
doesn't do*. That's what tells the next person whether upstream's new code makes
the commit redundant.

**Update the spec, don't `xit` it.** Three tests were disabled here rather than
adapted, and each one hid a real behaviour change: a manifest that had become a
redirect, and a waveform fix that was never actually applied.

**Fix upstream's copy when the bug is upstream's.** `git blame` before adding a
workaround. If it's their bug, PR it: group 1 has a much shorter half-life than
group 4.
