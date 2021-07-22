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

# Install FFMPEG
RUN mkdir -p /tmp/ffmpeg/bin \
 && cd /tmp/ffmpeg \
 && curl https://johnvansickle.com/ffmpeg/builds/ffmpeg-git-amd64-static.tar.xz | tar xJ \
 && cp $(find . -type f -executable) /tmp/ffmpeg/bin/

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
# Shared runtime image
FROM ruby:2.6.6-slim-stretch as runtime

RUN useradd -m -U app \
 && su -s /bin/bash -c "mkdir -p /home/app/vendor/gems" app

ENV RUNTIME_DEPS="git imagemagick libexif12 libexpat1 libgif7 glib-2.0 libgsf-1-114 libjpeg62-turbo libpng16-16 libpoppler-glib8 libpq5 libreoffice-core librsvg2-2 libsqlite3-0 libtiff5 libwrap0 libyaz4 locales mediainfo nodejs openjdk-8-jre-headless shared-mime-info sudo tzdata yarn" \
    DEBIAN_FRONTEND="noninteractive" \
    RAILS_ENV="production" \
    LANG="en_US.UTF-8"

RUN mkdir /usr/share/man/man1 \
 && apt-get update -qq \
 && apt-get install -y curl gnupg2 apt-transport-https ca-certificates --no-install-recommends \
 && curl -sL https://deb.nodesource.com/setup_12.x | bash - \
 && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
 && echo "deb http://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
 && curl -LO https://mediaarea.net/repo/deb/repo-mediaarea_1.0-16_all.deb \
 && dpkg -i repo-mediaarea_1.0-16_all.deb \
 && rm repo-mediaarea_1.0-16_all.deb \
 && apt-get update -qq \
 && apt-get install -y $RUNTIME_DEPS --no-install-recommends \
 && apt-get clean -y \
 && rm -rf /var/lib/apt/lists/* \
 && alias nodejs=node \
 && yarn add webpack \
 && dpkg-reconfigure -f noninteractive tzdata \
 && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
 && echo 'LANG="en_US.UTF-8"' > /etc/default/locale \
 && dpkg-reconfigure --frontend=noninteractive locales \
 && update-locale LANG=en_US.UTF-8

RUN gem update --system
COPY --from=ruby-deps /tmp/ffmpeg/bin/* /usr/local/bin/

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
