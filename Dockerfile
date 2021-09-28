####################################
# Build the bundle container
FROM ruby:2.6.6-slim-stretch as ruby-deps

ENV BUILD_DEPS="build-essential libpq-dev libsqlite3-dev libwrap0-dev libyaz4-dev tzdata locales git curl unzip shared-mime-info" \
    DEBIAN_FRONTEND="noninteractive" \
    RAILS_ENV="production" \
    LANG="en_US.UTF-8"

RUN useradd -m -U app \
 && su -s /bin/bash -c "mkdir -p /home/app" app

RUN apt-get update -qq \
 && apt-get install -y $BUILD_DEPS --no-install-recommends

# Set locale
RUN dpkg-reconfigure -f noninteractive tzdata \
 && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
 && echo 'LANG="en_US.UTF-8"'>/etc/default/locale \
 && dpkg-reconfigure --frontend=noninteractive locales \
 && update-locale LANG=en_US.UTF-8

RUN gem update --system \
 && chown -R app:staff /usr/local/bundle

USER app
WORKDIR /home/app

COPY --chown=app:app Gemfile* /home/app/
ENV BUNDLE_WITH='aws:postgres:zoom' BUNDLE_WITHOUT='development:test'
RUN bundle install --jobs $(nproc) --retry 5
RUN find /usr/local/bundle/ -name '*.gem' -or -name '*.c' -or -name '*.o' -delete
RUN rm -rf /usr/local/bundle/**/.git

####################################
# Build the npm dependency container
FROM node:12-stretch-slim as npm-deps

RUN apt-get update -qq \
 && apt-get install -y git
RUN useradd -m -U app \
 && su -s /bin/bash -c "mkdir -p /home/app"
WORKDIR /home/app
COPY --chown=app:app package.json yarn.lock /home/app/
RUN yarn install

####################################
# Precompile assets
FROM nulib/avr-runtime as assets

COPY --chown=app:staff --from=ruby-deps /usr/local/bundle /usr/local/bundle
COPY --chown=app:app --from=npm-deps /home/app/node_modules/ /home/app/node_modules/
COPY --chown=app:app . /home/app/

RUN mkdir /var/run/puma && chown root:app /var/run/puma && chmod 0775 /var/run/puma

USER app
WORKDIR /home/app
ENV BUNDLE_WITH='aws:postgres:zoom' BUNDLE_WITHOUT='development:test'
RUN bundle exec rake assets:precompile SECRET_KEY_BASE=$(ruby -r 'securerandom' -e 'puts SecureRandom.hex(64)')

####################################
# Build app image
FROM nulib/avr-runtime as app

COPY --chown=app:staff --from=ruby-deps /usr/local/bundle /usr/local/bundle
COPY --chown=app:app --from=npm-deps /home/app/node_modules/ /home/app/node_modules/
COPY --chown=app:app . /home/app/

RUN mkdir /var/run/puma && chown root:app /var/run/puma && chmod 0775 /var/run/puma

USER app
WORKDIR /home/app
ENV BUNDLE_WITH='aws:postgres:zoom' BUNDLE_WITHOUT='development:test'
COPY --from=assets /home/app/public/ /home/app/public/

EXPOSE 3000
ENV PATH="/home/app/bin:${PATH}"
CMD bin/boot_container
HEALTHCHECK --start-period=60s CMD curl -f http://localhost:3000/
