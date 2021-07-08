## Running AVR in Development Mode

This document explains how to run AVR in development with [devstack](https://github.com/nulib/devstack). It supersedes the development instructions in [README.md](README.md).

### One-Time Setup

The first time you prepare to run AVR on a new development system, there are a few prerequisites you need to install, update, and configure.

* Make sure your shell `rc` script (`~/.zshrc` or `~/.bashrc`) exports default values for both:
  * `AWS_PROFILE` (set to an actual configured AWS profile name, probably `staging`)
  * `AWS_REGION` (set to `us-east-1`)
* Pull `miscellany` repo
* `cd` to the Avalon/AVR working directory
* `devstack update`
* `asdf install ruby 2.6.7`
* `asdf local ruby 2.6.7`
* `gem install --no-doc bundler`
* `brew install postgresql`
* `brew install shared-mime-info`
* `brew install minio/stable/mc`
* `mc config host add dev https://devbox.library.northwestern.edu:9001 minio minio123`
* `ln -s /path/to/miscellany/avr/config/settings.local.yml config/settings.local.yml`
* `ln -s /path/to/miscellany/avr/config/settings/*.yml config/settings/`
* `bundle config set --local with puma:aws:postgres:ssl_dev:ezid`
* `bundle install`

### On a new stack

After bringing up an empty development stack (`devstack up [-d] avr`):

```shell
bundle exec rake zookeeper:upload zookeeper:create db:create db:migrate
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

### Using AVR

* Access the local site via `https://devbox.library.northwestern.edu:3001/`
* After logging in for the first time, open a new window (no need to shut down the server) and run `bundle exec rake avalon:user:admin`. Enter your northwestern email address to grant yourself admin rights.
* Refresh your browser window and make sure you see the `Manage` menu in the top nav bar

### Running rspec tests

```shell
bundle exec rspec -cf doc spec
```

**Note:** You might want to limit yourself to running whatever tests are relevant to the changes you've just made by replacing the `spec` at the end with the path to a specific test file or directory. The entire suite takes more than 45 minutes to run.
