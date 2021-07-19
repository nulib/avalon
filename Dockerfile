####################################
# Build the bundle container
FROM ruby:2.6.6-slim-stretch as ruby-deps

ENV BUILD_DEPS="build-essential libpq-dev libsqlite3-dev libwrap0-dev libyaz4-dev tzdata locales git curl unzip shared-mime-info" \
  DEBIAN_FRONTEND="noninteractive" \
  RAILS_ENV="production" \
  LANG="en_US.UTF-8"

RUN useradd -m -U app && \
  su -s /bin/bash -c "mkdir -p /home/app" app

RUN apt-get update -qq && \
  apt-get install -y $BUILD_DEPS --no-install-recommends

RUN \
  # Set locale
  dpkg-reconfigure -f noninteractive tzdata && \
  sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
  echo 'LANG="en_US.UTF-8"'>/etc/default/locale && \
  dpkg-reconfigure --frontend=noninteractive locales && \
  update-locale LANG=en_US.UTF-8 && \
  \
  mkdir -p /tmp/stage/bin && \
  \
  # Install FFMPEG
  mkdir -p /tmp/ffmpeg && \
  cd /tmp/ffmpeg && \
  curl https://s3.amazonaws.com/nul-repo-deploy/ffmpeg-release-64bit-static.tar.xz | tar xJ && \
  cp `find . -type f -executable` /tmp/stage/bin/

RUN gem update --system \
 && gem install bundler:2.2.20

USER app
WORKDIR /home/app

COPY --chown=app:app Gemfile* /home/app/
RUN bundle install --jobs 20 --retry 5 --with aws:postgres:zoom --without development:test --path vendor/gems && \
  rm -rf vendor/gems/ruby/*/cache/* vendor/gems/ruby/*/bundler/gems/*/.git

####################################
# Build the npm dependency container
FROM node:12-stretch-slim as npm-deps

RUN apt-get update -qq && \
    apt-get install -y git
RUN useradd -m -U app && \
  su -s /bin/bash -c "mkdir -p /home/app"
WORKDIR /home/app
COPY --chown=app:app package.json yarn.lock /home/app/
RUN yarn install

####################################
# Build the Application container
FROM ruby:2.6.6-slim-stretch as app

RUN useradd -m -U app && \
  su -s /bin/bash -c "mkdir -p /home/app/vendor/gems" app

ENV RUNTIME_DEPS="git imagemagick libexif12 libexpat1 libgif7 glib-2.0 libgsf-1-114 libjpeg62-turbo libpng16-16 libpoppler-glib8 libpq5 libreoffice-core librsvg2-2 libsqlite3-0 libtiff5 libwrap0 libyaz4 locales mediainfo nodejs openjdk-8-jre-headless shared-mime-info sudo tzdata yarn" \
  DEBIAN_FRONTEND="noninteractive" \
  RAILS_ENV="production" \
  LANG="en_US.UTF-8"

RUN \
  mkdir /usr/share/man/man1 && \
  apt-get update -qq && \
  apt-get install -y curl gnupg2 --no-install-recommends && \
  # Install NodeJS and Yarn package repos
  curl -sL https://deb.nodesource.com/setup_12.x | bash - && \
  curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
  echo "deb http://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
  # Install runtime dependencies
  apt-get update -qq && \
  apt-get install -y $RUNTIME_DEPS --no-install-recommends && \
  # Clean up package cruft
  apt-get clean -y && \
  rm -rf /var/lib/apt/lists/* && \
  # Install webpack
  alias nodejs=node && \
  yarn add webpack

RUN \
  # Set locale
  dpkg-reconfigure -f noninteractive tzdata && \
  sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
  echo 'LANG="en_US.UTF-8"'>/etc/default/locale && \
  dpkg-reconfigure --frontend=noninteractive locales && \
  update-locale LANG=en_US.UTF-8

RUN gem update --system \
 && gem install bundler:2.2.20

COPY --from=ruby-deps /tmp/stage/bin/* /usr/local/bin/
COPY --chown=app:staff --from=ruby-deps /usr/local/bundle /usr/local/bundle
COPY --chown=app:app --from=ruby-deps /home/app/vendor/gems/ /home/app/vendor/gems/
COPY --chown=app:app --from=npm-deps /home/app/node_modules/ /home/app/node_modules/
COPY --chown=app:app . /home/app/

RUN mkdir /var/run/puma && chown root:app /var/run/puma && chmod 0775 /var/run/puma

USER app
WORKDIR /home/app
RUN bundle exec rake assets:precompile SECRET_KEY_BASE=$(ruby -r 'securerandom' -e 'puts SecureRandom.hex(64)')

EXPOSE 3000
ENV BUNDLE_PATH="vendor/gems"
ENV PATH="/home/app/bin:${PATH}"
CMD bin/boot_container
HEALTHCHECK --start-period=60s CMD curl -f http://localhost:3000/
