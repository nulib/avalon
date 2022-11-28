## Running AVR in Development Mode

This document explains how to run AVR in the [remote development environment](http://docs.rdc.library.northwestern.edu/2._Developer_Guides/Environment_and_Tools/Remote-Development-Environment-FAQ/). It supersedes the development instructions in [README.md](README.md).

### One-Time Setup

The first time you prepare to run AVR on a new development system, there are a few prerequisites you need to install, update, and configure.

* `cd` to the Avalon/AVR working directory
* `asdf plugin add ruby`
* `asdf install ruby 2.6.7`
* `asdf local ruby 2.6.7`
* `gem install --no-doc bundler`
* `app-environment avr`
* Create `config/settings/development.local.yml`:
  ```
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
* `bundle config set --local with puma:aws:postgres:ssl_dev:ezid`
* `bundle config set --local build.zookeeper --with-cflags=-Wno-error=format-overflow`
* `bundle install`
* `asdf plugin add yarn`
* `asdf install yarn 1.22.19`
* `asdf local yarn 1.22.19`
* `yarn install`

### Initializing/Clearing the Development Stack

Non-destructive:
```shell
bundle exec rake avr:setup
```

Destructive (clear data and empty buckets):
```shell
bundle exec rake avr:reset
```

For the test environment, prefix either command with `RAILS_ENV=test `, e.g.:

```shell
RAILS_ENV=test bundle exec rake avr:setup
```

### Making sure the Samvera Stack (Fedora/Solr/Redis) is running

```shell
curl $SETTINGS__FEDORA__URL
```

If Fedora does not respond immediately, run the following, and then wait 3-4 minutes and try again:

```shell
aws ecs update-service --cluster dev-environment --service samvera-stack --desired-count 1 --no-cli-pager
```

### Starting the server and background workers

```shell
bundle exec guard -i
```

### Using AVR

* Make sure port 3001 is open (`sg open all 3001`)
* Access the local site via `https://DEV_PREFIX.dev.rdc.library.northwestern.edu:3001/`
* After logging in for the first time, open a new window (no need to shut down the server) and run `bundle exec rake avalon:user:admin`. Enter your northwestern email address to grant yourself admin rights.
* Refresh your browser window and make sure you see the `Manage` menu in the top nav bar

### Running rspec tests

**Note: The test suite is currently not usable in the dev environment. These instructions will be updated if necessary once that's worked out.**

```shell
bundle exec rspec -cf doc spec
```

**Note:** You might want to limit yourself to running whatever tests are relevant to the changes you've just made by replacing the `spec` at the end with the path to a specific test file or directory. The entire suite takes more than 45 minutes to run.

### Last One Out, Please Shut Off the Lights

When finished with the Samvera stack:

```shell
aws ecs update-service --cluster dev-environment --service samvera-stack --desired-count 0 --no-cli-pager
```

Don't worry if you forget; the daily spin-down task will shut it down at the end of the day.
