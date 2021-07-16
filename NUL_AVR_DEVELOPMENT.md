## Running AVR in Development Mode

This document explains how to run AVR in development with [devstack](https://github.com/nulib/devstack). It supersedes the development instructions in [README.md](README.md).

### One-Time Setup

The first time you prepare to run AVR on a new development system, there are a few prerequisites you need to install, update, and configure.

* Pull `miscellany` repo
* `cd` to the Avalon/AVR working directory
* `devstack update`
* `asdf install ruby 2.6.7`
* `asdf local ruby 2.6.7`
* `brew install minio/stable/mc`
* `mc config host add dev https://devbox.library.northwestern.edu:9001 minio minio123`
* `ln -s /path/to/miscellany/avr/config/settings.local.yml config/settings.local.yml`
* `ln -s /path/to/miscellany/avr/config/settings/*.yml config/settings/`

### On a new stack

After bringing up an empty development stack (`devstack up [-d] avr`):

```shell
bundle exec rake zookeeper:upload zookeeper:create db:create db:migrate avr:create_queues
mc mb -p dev/fcrepo dev/masterfiles dev/derivatives dev/supplementalfiles
mc policy set download dev/derivatives
mc policy set download dev/supplementalfiles
```

After bringing up the test stack (`devstack -t up [-d] avr`):

```shell
RAILS_ENV=test bundle exec rake zookeeper:upload zookeeper:create db:create db:migrate
```

### Starting the server and background workers

```shell
bundle exec guard -i
```

### Running rspec tests

```shell
bundle exec rspec -cf doc spec
```

**Note:** You might want to limit yourself to running whatever tests are relevant to the changes you've just made by replacing the `spec` at the end with the path to a specific test file or directory. The entire suite takes more than 45 minutes to run.
