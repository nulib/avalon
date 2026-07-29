# Running AVR in development

Supersedes the development instructions in [README.md](../README.md), which
describe upstream Avalon's docker-compose stack. AVR runs natively against real
AWS services in the
[remote development environment](http://docs.rdc.library.northwestern.edu/2._Developer_Guides/Environment_and_Tools/Remote-Development-Environment-FAQ/).

See also [AVR_CUSTOMIZATIONS.md](AVR_CUSTOMIZATIONS.md) for what differs from
upstream, and [AVR_UPGRADE.md](AVR_UPGRADE.md) for rebasing onto a new release.

## One-time setup

From the AVR working directory:

```bash
# Ruby version tracks the base image in the Dockerfile (`FROM ruby:...`).
mise use ruby@4
gem install --no-document bundler -v "$(grep -A 1 'BUNDLED WITH' Gemfile.lock | tail -n 1 | tr -d ' ')"

# Populates .envrc with the SETTINGS__* and DATABASE_URL values for the
# environment. `direnv allow` afterwards if direnv prompts.
app-environment avr

# The zookeeper gem needs this on current compilers.
bundle config set --local build.zookeeper --with-cflags=-Wno-error=format-overflow
bundle config set --local with 'aws development test postgres'
bundle config set --local without 'production'
bundle install

yarn install

cp -n config/controlled_vocabulary.yml.example config/controlled_vocabulary.yml
```

`app-environment` writes the `SETTINGS__*` exports that stand in for SSM
Parameter Store — in a deployed container these come from
`config/initializers/_aws_config.rb` instead. `SSM_PARAM_PATH` is deliberately
unset locally, so that initializer no-ops.

`config/settings/development.local.yml` is the place for anything you need to
override that isn't in `.envrc`, e.g. MediaConvert output presets:

```yaml
encoding:
  media_convert:
    configuration:
      mapping:
        '720': high
        '540': low
      options:
        avalon:
          media_type: video
          outputs:
            - preset: avr-video-medium
              modifier: "-720"
            - preset: avr-video-low
              modifier: "-540"
        fullaudio:
          media_type: audio
          outputs:
            - preset: avr-audio-high
              modifier: "-high"
            - preset: avr-audio-medium
              modifier: "-medium"
```

## Databases and search

AVR uses PostgreSQL in every environment (see `config/database.yml`), plus
Fedora and SolrCloud from the shared dev stack.

```bash
bundle exec rake db:setup zookeeper:upload zookeeper:create

# and for the test environment
RAILS_ENV=test bundle exec rake db:setup zookeeper:upload zookeeper:create
```

`rake avalon:services:{start,stop,status,restart}` manages the dependent
services.

## Background jobs

AVR's ActiveJob adapter is Shoryuken/SQS, not Sidekiq. The worker's queue list
is generated from the job classes in the app, so create it — and the queues —
before starting a worker:

```bash
bundle exec rake shoryuken:create_config shoryuken:create_queues
```

`config/shoryuken.yml` is gitignored; re-run `shoryuken:create_config` after
adding an ActiveJob subclass or changing `active_job.queue_name_prefix`.

## Running the app

```bash
bundle exec guard -i
```

That runs Puma and a Shoryuken worker together, restarting both on changes to
`app/`, `config/`, `lib/`, or `api/`. To run just one:

```bash
bundle exec puma -C config/puma.rb
bundle exec shoryuken --config=config/shoryuken.yml --rails
```

`config/puma.rb` adds a TLS listener when `SSL_CERT` and `SSL_KEY` are set, which
`app-environment` does. That matters: `Settings.domain.protocol` is `https`, and
both the SSO and LTI handshakes need a real https origin. Reach the site at:

```
https://DEV_PREFIX.dev.rdc.library.northwestern.edu:3001/
```

## Granting yourself admin

Log in once through SSO so a `User` record exists, then, without stopping the
server:

```bash
bundle exec rake avalon:user:admin
```

Enter your Northwestern **email address** — AVR's user key is email, not NetID
(see `config/initializers/devise.rb`). Refresh and you should have the `Manage`
menu.

## Tests

```bash
bundle exec rspec spec
bundle exec rspec spec/services/canvas_service_spec.rb   # or a single file
```

The full suite takes upwards of 45 minutes, so prefer scoping it while you work
and let CI run the whole thing.

Two things worth knowing about the test environment:

- `config.use_env` is off in test (`config/initializers/config.rb`), so the
  `SETTINGS__*` variables in your shell do **not** reach `Settings`. This is
  deliberate — otherwise specs pass or fail depending on whose shell they run in.
  Set test values in `config/settings/test.local.yml`.
- AVR customizations in specs are marked `# AVR customization`, so
  `grep -rn 'AVR customization' spec/` lists them.

## Which service is this talking to?

Local development runs against real AWS resources, with these exceptions:

| | |
| --- | --- |
| Settings | `.envrc` (`SETTINGS__*`), not SSM. `SSM_PARAM_PATH` is unset. |
| Canvas | No-ops unless `Settings.canvas.api.token` is set. |
| Streaming | Real CloudFront, real signing key. Playback works locally. |
| Background jobs | Real SQS queues, namespaced by `active_job.queue_name_prefix`. |
| Encoding | Real MediaConvert. Check your presets exist before ingesting. |
