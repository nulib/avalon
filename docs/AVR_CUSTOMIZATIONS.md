# AVR customizations

Every way AVR differs from the upstream Avalon release it is built on, why, and
where. Keep this current — [AVR_UPGRADE.md](AVR_UPGRADE.md) assumes it is
accurate when deciding whether a customization is still needed.

The authoritative list is always the commit stack itself:

```bash
git log --oneline --reverse v8.2..HEAD
git diff --stat v8.2 HEAD -- . ':(exclude)terraform' ':(exclude)Gemfile.lock'
```

## Group 1 — fixes on their way upstream

Each is one commit, self-contained and PR-able. These disappear from the stack
when they merge upstream; `git rebase` drops them by patch-id.

| Fix | Files | Status |
| --- | --- | --- |
| `@current_package` left set after a failed batch validation | `lib/avalon/batch/ingest.rb` | in [#6925](https://github.com/avalonmediasystem/avalon/pull/6925) |
| `WaveformJob` downloaded whole S3 objects to local temp files | `app/services/waveform_service.rb` | in #6925 |
| HLS manifests HTML-encoded their URLs | `app/views/master_files/hls_manifest.m3u8.erb` | in #6925 |
| Invalid `sort` param 500s instead of 400s | `app/controllers/catalog_controller.rb` | in #6925 |
| Ramp player and structure editor didn't send credentials cross-origin | `app/javascript/components/{MediaObjectRamp,ReactButtonContainer}.jsx` | in #6925 |
| Spaces in streaming URLs weren't encoded | `app/services/security_service.rb` | in #6925 |
| Poster generation raised on a blank `file_location` | `app/models/master_file.rb` | in #6925 |
| `rewrite_v4_ids` 404s instead of falling through | `app/controllers/application_controller.rb` | not yet PR'd |
| `stream_token_ttl` arrives from SSM as a String | `app/models/stream_token.rb` | not yet PR'd |
| `gather_hls_streams` appends a second `auto` quality | `app/models/concerns/master_file_behavior.rb` | not yet PR'd |
| Multi-valued `terms_of_use` serialized as `Array#inspect` in MODS | `app/models/mods_templates.rb` | not yet PR'd |
| webpack `--mode` never reaches `BABEL_ENV`, so prod bundles call `jsxDEV` | `config/webpack/webpack.config.js` | not yet PR'd |

The last five are all worth PR-ing. Two of them (`to_f` on a Settings value,
`rewrite_v4_ids` falling through) only matter to a deployment shaped like AVR's,
but the other three are plain bugs.

## Group 2 — infrastructure and build

### Terraform (`terraform/`)

The whole AWS environment: ECS cluster and services, CloudFront distributions
for the app and for streaming, S3 buckets, SQS queues, the MediaConvert queue,
the AIFF and batch-ingest Lambdas, and the SSM parameters that populate
`Settings` at boot.

Self-contained, and upstream has no `terraform/` directory, so it never
conflicts. Deployed separately from the app.

`terraform/settings.tf` is the source of truth for deployed configuration. A new
setting a release needs goes there, not into `config/settings/production.yml`.

### GitHub Actions (`.github/`)

Replaces upstream's CircleCI config, which builds against
`avalonmediasystem/avalon` images and can't produce AVR's image or drive our ECS
deployments. `.circleci/config.yml` is deleted, but **keep reading it on every
upgrade** — the test job's service container versions have to track it.

Upstream's own `.github/workflows/{podman-image,update-ramp}.yml` are left alone.

### Container entrypoint (`Dockerfile`, `bin/boot_container`, `config/puma_container.rb`)

The `Dockerfile` is upstream's file verbatim plus two marked blocks:

1. `COPY Gemfile.local` in the `bundle` stage. Upstream copies only `Gemfile`
   and `Gemfile.lock` before `bundle install`; without this, upstream's
   `eval_gemfile 'Gemfile.local' if File.exist?` silently does nothing, so AVR's
   gems are resolved out and the git-sourced ones never get checked out —
   surfacing two stages later as `omniauth-nusso ... is not yet checked out`
   during `assets:precompile`.
2. At the end of the `prod` stage: a writable `/var/run/puma`, `EXPOSE`,
   `HEALTHCHECK`, and `CMD ["bin/boot_container"]`.

`bin/boot_container` dispatches on `$CONTAINER_ROLE`, set per task definition in
`terraform/modules/avr_task`, so one image serves all three roles:

| `CONTAINER_ROLE` | Runs |
| --- | --- |
| `migrate` | `rake db:migrate zookeeper:upload zookeeper:create`, then exits |
| `worker` | `rake shoryuken:create_config` then `shoryuken` |
| anything else | `puma -C config/puma_container.rb` |

## Group 3 — runtime plumbing

### Settings from SSM Parameter Store (`config/initializers/_aws_config.rb`)

Merges every parameter under `$SSM_PARAM_PATH/Settings` into `Settings` at boot,
mapping parameter paths onto nested keys:

```
/avr/staging/Settings/streaming/http_base  ->  Settings.streaming.http_base
```

No-ops when `SSM_PARAM_PATH` is unset, which is how development, test, and CI
run. **The leading underscore in the filename is load-order significant** —
initializers load alphabetically and this has to run before anything reads
`Settings`.

`config/initializers/logging_config.rb` exists for the same reason: Rails reads
`config.log_level` too early in boot for an SSM-sourced value to have landed.

`config/initializers/config.rb` turns off `config.use_env` in test, because
developers work against a live AWS environment with a large set of `SETTINGS__*`
variables exported (see `.envrc`), and those would otherwise change spec results
depending on whose shell they ran in.

### Background jobs on SQS (`config/application.rb`, `config/shoryuken.yml.erb`, `lib/tasks/shoryuken.rake`)

AVR runs on Fargate with no Redis, so ActiveJob points at Shoryuken/SQS. Adapter,
queue prefix, and delimiter all come from `Settings`, so `config/application.rb`
stays adapter-agnostic and Sidekiq is still the default:

```yaml
active_job:
  queue_adapter: shoryuken
  queue_name_prefix: avr-staging
  queue_name_delimiter: '-'
  default_queue_name: default
```

`rake shoryuken:create_config` derives the worker's queue list from the
ActiveJob subclasses actually defined in the app and writes
`config/shoryuken.yml` (gitignored); `rake shoryuken:create_queues` creates the
SQS queues from it. The worker runs `create_config` at boot, so a newly added job
class gets a queue without a config change.

`config/initializers/sidekiq.rb` skips upstream's sidekiq-cron registration
unless the Sidekiq adapter is in use — see **Known gaps**.

### ActiveStorage from Settings (`config/application.rb`)

Upstream picks a service by name from `Settings` but reads the definitions from
`config/storage.yml`, which is baked into the image. AVR lets `Settings` supply
`active_storage.service_configurations` too, so the bucket and region can come
from SSM.

### `Gemfile.local`

AVR's gems: `aws-sdk-ssm`, `omniauth-nusso`, `omniauth-rails_csrf_protection`,
`shoryuken`, and `guard-puma`/`guard-process` for development.

Upstream's `Gemfile` already evals this file if it exists, so **`Gemfile` itself
needs no AVR change** — which is why `git diff <tag> -- Gemfile` should always be
empty. Upstream gitignores `Gemfile.local` as a local escape hatch; `.gitignore`
un-ignores it explicitly.

## Group 4 — product customizations

### Authentication: email as the user key

`config/initializers/devise.rb` sets `authentication_keys = [:email, :username]`.
The order matters and is the entire point:
`Blacklight::AccessControls::User#user_key` and `Hydra.config.user_key_field`
both resolve to `Devise.authentication_keys.first`, so putting `:email` first is
what makes email the access-control identity for the whole app.

Because upstream looks users up with
`User.where(Devise.authentication_keys.first => value)` — one key only —
`User.find_by_devise_authentication_keys` accepts either key, case-insensitively,
excluding soft-deleted users, and returns a relation. Callers: the admin
collection and unit controllers, `lib/tasks/avalon.rake`,
`Avalon::Batch::Package`, `AccessControlStep`.

Northwestern SSO itself is `omniauth-nusso`, configured through
`Settings.auth.configuration` (from SSM). No code in this repo.

### Canvas course integration

Course reserves are visible to students enrolled in the course, so AVR needs
*every* course a user is currently enrolled in — not just the one `context_id` of
the LTI launch they arrived through, which is all upstream has.

- `app/services/canvas_service.rb` — Canvas REST client; no-ops with no token
  configured. Always returns a Hash from `courses_for_user`.
- `User#canvas_courses` / `User#virtual_groups` — LDAP groups plus a group per
  current Canvas course.
- `Users::OmniauthCallbacksController`, `Samvera::Persona::UsersController` —
  populate `user_session[:virtual_groups]` from `virtual_groups`. The LTI branch
  deliberately drops upstream's two lines that add the launch `context_id` as a
  group and mark the session a partial login: an LTI launch at Northwestern is
  backed by a real NetID, and enrollment already covers the courses.
- `ApplicationHelper#vgroup_display` — cached; the facet renders dozens of
  values per page.
- `config/locales/nu_avr.en.yml` — relabels the facet "Course".
- `config/lti.yml` — LTI parameter mappings per tool consumer (Canvas, legacy
  Canvas, Ares). **No secrets**; the shared secrets are in
  `Settings.auth.configuration`. Upstream gitignores this file on the assumption
  it holds them.
- `config/initializers/avalon_lti.rb` — registers uppercase aliases for the OAuth
  signature methods, which is how Canvas sends them.

### CloudFront stream security

`app/services/security_service.rb` signs stream **URLs** as well as cookies,
because AVR redirects the player straight at the pre-rendered playlist on
CloudFront (below) rather than proxying it. Uses
`Aws::CloudFront::{Url,Cookie}Signer` instead of upstream's `cloudfront-signer`
gem, which configures a single process-wide signer that can't be re-keyed and
offers no URL signing. (`cloudfront-signer` stays in upstream's `Gemfile`;
removing it would be Gemfile conflict for no gain.)

`#cookie_domain` also fixes upstream's, which intersects the app and streaming
hosts' label *sets* — order- and position-blind, so for
`avr.library.northwestern.edu` and `stream.avr.library.northwestern.edu` it
returns a domain the streaming host isn't under and the browser drops the cookie.
AVR walks in from the TLD instead.

**If playback breaks after an upgrade, look here first.**

### Pre-rendered adaptive streaming playlists

MediaConvert writes a real HLS playlist per quality to S3 alongside the segments,
so `MasterFilesController#hls_manifest` redirects to the signed CloudFront URL
for a specific quality rather than generating a manifest. Only the `auto`
multivariant manifest is still assembled in Rails, and only when MediaConvert
didn't already produce one.

### Legacy URL redirects

Most non-course media has moved to Digital Collections, but the old AVR URLs are
still in syllabi, course sites, and citations. A row in `redirects` sends a
request for that identifier to its new home instead of 404ing.

- `Redirect` (`app/models/redirect.rb`) plus
  `db/migrate/20260729000000_create_redirects.rb`. String primary key, not
  necessarily a NOID: a v4/v5 Avalon id, a legacy PID, or a collection name.
- `ApplicationController#maybe_redirect` — `before_action` on the show actions of
  MediaObjects, MasterFiles (item and embed targets), Collections, Objects.
- `CatalogController#redirect_specific_collection_facets` — a search faceted to a
  single moved collection is in practice a link to that collection.

Rows are loaded in bulk out of band; there is no UI.

### Branding and content

- `app/views/catalog/_nu_home.html.erb` — AVR's home page, chiefly the notice
  that non-course media now lives in Digital Collections.
  `catalog/index.html.erb`'s AVR delta is the one line that renders it.
- `config/nu_vocab.yml` + `config/settings/production.yml` — NU's units and
  identifier types. Development points at the same file via
  `SETTINGS__CONTROLLED_VOCABULARY__PATH` in `.envrc`; **test uses upstream's**.
- `app/views/modules/_google_analytics.html.erb` +
  `app/helpers/google_tag_manager_helper.rb` — a GTM container
  (`Settings.analytics_container_id`) in place of upstream's GA4 gtag loader.
  Overriding the partial upstream already renders means neither layout is
  touched.
- `ApplicationHelper#https_url` — upgrades a stored permalink's scheme. Generated
  URLs are already https via `Settings.domain.protocol`.

### API

`MediaObjectsController#create` returns 422 when `collection_id` is missing.
`update_media_object` only validates it when supplied, which is right for
`json_update` but means a create without one fails a later validation with a
message that doesn't name the cause.

## Group 5 — development environment and dependency locks

- `config/database.yml` — PostgreSQL. Deployed environments get a `DATABASE_URL`
  from the ECS task definition.
- `config/puma.rb` — upstream's file plus an `ssl_bind` guarded on
  `SSL_CERT`/`SSL_KEY`, for the remote development environment. Deployed
  containers use `config/puma_container.rb` instead.
- `Guardfile` — `bundle exec guard -i` runs the app and a Shoryuken worker.
- `Gemfile.lock` — regenerated, never merged. See
  [AVR_UPGRADE.md](AVR_UPGRADE.md#3-regenerate-the-dependency-locks).

## Deliberately *not* customized

Things a reader might expect to find here, and why they aren't:

| | |
| --- | --- |
| `Gemfile`, `package.json`, `yarn.lock` | Identical to upstream. AVR's gems live in `Gemfile.local`; the earlier `react_on_rails`/`react-on-rails` pins were redundant, since upstream's `^14.2.1` already excludes 15+. |
| `app/views/layouts/*` | Identical to upstream. Analytics goes through the partial they already render. |
| `Dockerfile` above the AVR block | Verbatim upstream, including ruby 4 / node 24 on bookworm, jemalloc, and YJIT. |
| `zoom` / `yaz` | Nothing to do. AVR uses the SRU bib retriever, which is upstream's default; the `zoom` group is `optional: true` in upstream's `Gemfile`, so it is never installed unless explicitly requested. |
| `cloudfront-signer` | Unused by AVR but upstream's dependency, so removing it is a Gemfile conflict for no benefit. |
| `google-analytics-rails` | Same: Avalon 8.2 doesn't use it either. |
| `bin/run`, `Dockerfile.runtime` | Deleted. `bin/run` ran `sudo -u app` in an image that is already `USER app` with no sudoers entry. `Dockerfile.runtime` was an unreferenced AVR-7.x file pinning ruby 2.6.6, Debian stretch, node 12, and openjdk-8 — and was the only remaining reference to `libyaz4`. |
| Redis cache namespace | Upstream's `namespace: 'avalon'` is restored. AVR had removed it in a commit about the Docker build. |

## Known gaps

Real, known, unfixed. Listed so they don't have to be rediscovered.

**No AVR branding.** The home page markup referenced `.hero-image`,
`.contain-1120`, `.contain-970`, `.section-top`, and `.full-width-page`, none of
which exist in this repo: they lived in
`app/assets/stylesheets/northwestern/`, dropped during the 8.x upgrade and never
replaced. So from that upgrade until the restructure, the home page rendered
completely unstyled. `_nu_home.html.erb` now uses the Bootstrap 5 utilities
Avalon 8 ships, which is presentable but is not AVR branding. The old
stylesheets are still on the `avr-pre-upgrade` branch.

**Two scheduled jobs have no replacement.** Skipping sidekiq-cron dropped five
periodic jobs. Three are covered by AWS: `BatchScanJob` by
`terraform/batch_lambda.tf` (on S3 object-created), and `CleanupSessionJob` and
the `searches` cleanup by the EventBridge rule in `terraform/maintenance.tf`.
Not covered:

- **`CleanupStreamTokenJob`** — the `stream_tokens` table is never pruned. Adding
  it to the maintenance Lambda isn't a straight port: that Lambda deletes by row
  age, and stream tokens expire on an `expires` column.
- **`IngestBatchStatusEmailJobs::{IngestFinished,StalledJob}`** — nobody is
  notified when a batch finishes or stalls.

**The GitHub Actions test job has never been verified green.** Its service
containers were on Fedora 4.7.5 and Solr 7.2 — AVR-7.x versions that Avalon 8's
configset can't run against — and its actions were pinned to majors that run on
retired runner images. They have been brought in line with upstream's CircleCI
config, but the suite has not been run to completion in CI. Expect to iterate.

**`config/nu_vocab.yml` is not used in test.** It is selected by
`config/settings/production.yml` in production and by `.envrc` in development,
but nothing points at it in test, so specs run against upstream's example
vocabulary and its "Default Unit".

**The Course facet is no longer filtered per user.** AVR used to suppress Course
facet values the current user wasn't enrolled in, via
`Blacklight::LocalBlacklightHelper#render_facet_item` — so that a manager's facet
list wasn't a directory of every course in Canvas. Blacklight 8 renders facet
items through ViewComponents and calls no such helper (the name survives only in
a comment in `Blacklight::FacetFieldListComponent` describing the removed
behaviour), so the override and its `hide_course_from_user?` companion have been
dead code since the 8.x upgrade. They're removed rather than left to look load-bearing.

To reinstate it on Blacklight 8: facet fields take an `item_component:`, so
subclass `Blacklight::FacetItemComponent` and override ViewComponent's `render?`
to return false when `helpers.current_user` isn't enrolled in `@facet_item.value`
(`@facet_item` is set in that component's `initialize`), then pass the subclass
as `item_component:` on the `read_access_virtual_group_ssim` facet in
`CatalogController`. Not done here because it needs a rendered page to verify,
and getting it wrong errors the facet for managers rather than merely
over-disclosing.

**Canvas enrollment lookups aren't cached.** `CanvasService.find_course` uses
`Rails.cache`, but `find_user` and `courses_for_user` don't — and each
`courses_for_user` is at least four paginated Canvas API calls (search for the
user, then walk their courses). That runs on every login, and again on any
request that renders the Course facet, since
`Blacklight::LocalBlacklightHelper#hide_course_from_user?` reads
`current_user.canvas_courses`. It is memoized per `User` instance, so it's once
per request rather than once per facet value, but a Canvas outage or slowdown
becomes an AVR outage. Caching `courses_for_user` per NetID with a short TTL is
the obvious fix; the reason not to do it blind is that shortening the window in
which a new enrollment takes effect is a policy decision.
