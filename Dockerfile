# Base stage for building gems
FROM        ruby:3.2-bullseye as bundle
LABEL       stage=build
LABEL       project=avalon
RUN        apt-get update && apt-get upgrade -y build-essential && apt-get autoremove \
         && apt-get install -y --no-install-recommends --fix-missing \
            cmake \
            pkg-config \
            zip \
            git \
            ffmpeg \
            libsqlite3-dev \
         && rm -rf /var/lib/apt/lists/* \
         && apt-get clean

ENV BUILD_DEPS="build-essential libpq-dev libsqlite3-dev libwrap0-dev libyaz4-dev tzdata locales git curl unzip shared-mime-info" \
  DEBIAN_FRONTEND="noninteractive" \
  RAILS_ENV="production" \
  LANG="en_US.UTF-8"

RUN useradd -m -U app && \
  su -s /bin/bash -c "mkdir -p /home/app" app

ENV         RUBY_THREAD_MACHINE_STACK_SIZE 8388608
ENV         RUBY_THREAD_VM_STACK_SIZE 8388608


# Build development gems
FROM        bundle as bundle-dev
LABEL       stage=build
LABEL       project=avalon
RUN         bundle config set --local without 'production' \
         && bundle config set --local with 'aws development test postgres' \
         && bundle install

RUN gem update --system \
 && chown -R app:staff /usr/local/bundle

# Download binaries in parallel
FROM        ruby:3.2-bullseye as download
LABEL       stage=build
LABEL       project=avalon
RUN         curl -L https://github.com/jwilder/dockerize/releases/download/v0.6.1/dockerize-linux-amd64-v0.6.1.tar.gz | tar xvz -C /usr/bin/
RUN         curl https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o /chrome.deb
RUN         chrome_version=`dpkg-deb -f /chrome.deb Version | cut -d '.' -f 1-3`
RUN         chromedriver_version=`curl https://chromedriver.storage.googleapis.com/LATEST_RELEASE_${chrome_version}`
RUN         curl https://chromedriver.storage.googleapis.com/index.html?path=${chromedriver_version} -o /usr/local/bin/chromedriver \
         && chmod +x /usr/local/bin/chromedriver
RUN      apt-get -y update && apt-get install -y ffmpeg

COPY --chown=app:app Gemfile* /home/app/
ENV BUNDLE_WITH='aws:postgres:zoom' BUNDLE_WITHOUT='development:test'
RUN bundle install --jobs 20 --retry 5 \
 && rm -rf /usr/local/bundle/cache/* /usr/local/bundle/bundler/gems/*/.git

# Base stage for building final images
FROM        ruby:3.2-slim-bullseye as base
LABEL       stage=build
LABEL       project=avalon
RUN         echo "deb     http://ftp.us.debian.org/debian/    bullseye main contrib non-free"  >  /etc/apt/sources.list.d/bullseye.list \
         && echo "deb-src http://ftp.us.debian.org/debian/    bullseye main contrib non-free"  >> /etc/apt/sources.list.d/bullseye.list \
         && cat /etc/apt/sources.list.d/bullseye.list \
         && mkdir -p /etc/apt/keyrings \
         && apt-get update && apt-get install -y --no-install-recommends curl ca-certificates gnupg2 ffmpeg \
         && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
         && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" > /etc/apt/sources.list.d/nodesource.list \
         && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
         && echo "deb http://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
         && cat /etc/apt/sources.list.d/nodesource.list \
         && cat /etc/apt/sources.list.d/yarn.list

RUN         apt-get update && \
            apt-get -y dist-upgrade && \
            apt-get install -y --no-install-recommends --allow-unauthenticated \
            nodejs \
            yarn \
            lsof \
            x264 \
            sendmail \
            git \
            libxml2-dev \
            libxslt-dev \
            libpq-dev \
            openssh-client \
            zip \
            dumb-init \
            libsqlite3-dev \
         && apt-get -y install mediainfo \
         && ln -s /usr/bin/lsof /usr/sbin/

RUN         useradd -m -U app \
         && su -s /bin/bash -c "mkdir -p /home/app/avalon" app
WORKDIR     /home/app/avalon


# Build devevelopment image
FROM        base as dev
LABEL       stage=final
LABEL       project=avalon
RUN         apt-get update && apt-get install -y --no-install-recommends --allow-unauthenticated \
            build-essential \
            cmake

COPY --from=ruby-deps /tmp/stage/bin/* /usr/local/bin/
COPY --chown=app:staff --from=ruby-deps /usr/local/bundle /usr/local/bundle
COPY --chown=app:app --from=npm-deps /home/app/node_modules/ /home/app/node_modules/
COPY --chown=app:app . /home/app/

RUN mkdir /var/run/puma && chown root:app /var/run/puma && chmod 0775 /var/run/puma

USER app
WORKDIR /home/app
ENV BUNDLE_WITH='aws:postgres:zoom' BUNDLE_WITHOUT='development:test'
RUN bundle exec rake assets:precompile SECRET_KEY_BASE=$(ruby -r 'securerandom' -e 'puts SecureRandom.hex(64)')

# Build production gems
FROM        bundle as bundle-prod
LABEL       stage=build
LABEL       project=avalon
RUN         bundle config set --local without 'development test' \
         && bundle config set --local with 'aws production postgres' \
         && bundle install


# Install node modules
FROM        node:20-bullseye-slim as node-modules
LABEL       stage=build
LABEL       project=avalon
RUN         apt-get update && apt-get install -y --no-install-recommends git ca-certificates
COPY        package.json .
COPY        yarn.lock .
RUN         yarn install


# Build production assets
FROM        base as assets
LABEL       stage=build
LABEL       project=avalon
COPY        --from=bundle-prod --chown=app:app /usr/local/bundle /usr/local/bundle
COPY        --chown=app:app . .
COPY        --from=node-modules --chown=app:app /node_modules ./node_modules

USER        app
ENV         RAILS_ENV=production

RUN         SECRET_KEY_BASE=$(ruby -r 'securerandom' -e 'puts SecureRandom.hex(64)') bundle exec rake assets:precompile
RUN         cp config/controlled_vocabulary.yml.example config/controlled_vocabulary.yml


# Build production image
FROM        base as prod
LABEL       stage=final
LABEL       project=avalon
COPY        --from=assets --chown=app:app /home/app/avalon /home/app/avalon
COPY        --from=bundle-prod --chown=app:app /usr/local/bundle /usr/local/bundle

USER        app
ENV         RAILS_ENV=production
