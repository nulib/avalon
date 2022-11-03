## Running AVR in Development Mode

This document explains how to run AVR in the [remote development environment](http://docs.rdc.library.northwestern.edu/2._Developer_Guides/Environment_and_Tools/Remote-Development-Environment-FAQ/). It supersedes the development instructions in [README.md](README.md).

### One-Time Setup

The first time you prepare to run AVR on a new development system, there are a few prerequisites you need to install, update, and configure.

* `cd` to the Avalon/AVR working directory
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

### Initializing/Clearing the Development Stack

```shell
bundle exec rake avr:reset
```

or for the test environment:

```shell
RAILS_ENV=test bundle exec rake avr:reset
```

### Starting the server and background workers

```shell
bundle exec guard -i
```

### Using AVR

* Access the local site via `https://DEV_PREFIX.dev.rdc.library.northwestern.edu:3001/`
* After logging in for the first time, open a new window (no need to shut down the server) and run `bundle exec rake avalon:user:admin`. Enter your northwestern email address to grant yourself admin rights.
* Refresh your browser window and make sure you see the `Manage` menu in the top nav bar

### Running rspec tests

**Note: The test suite is currently not usable in the dev environment. These instructions will be updated if necessary once that's worked out.**

```shell
bundle exec rspec -cf doc spec
```

**Note:** You might want to limit yourself to running whatever tests are relevant to the changes you've just made by replacing the `spec` at the end with the path to a specific test file or directory. The entire suite takes more than 45 minutes to run.
