require File.expand_path('../boot', __FILE__)

require 'rails/all'
require 'resolv-replace'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Avalon
  VERSION = '6.3.2'

  class Application < Rails::Application
    require 'avalon/configuration'

    config.generators do |g|
      g.test_framework :rspec, :spec => true
    end


    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Do not swallow errors in after_commit/after_rollback callbacks.
    config.active_record.raise_in_transactional_callbacks = true

    begin
      require Settings.active_job.queue_adapter.to_s
    rescue LoadError
    end
    config.active_job.queue_adapter = Settings.active_job.queue_adapter.to_s

    if ENV['REDIS_HOST']
      redis_host = ENV['REDIS_HOST']
      redis_port = ENV['REDIS_PORT'] || 6379

      config.cache_store = :redis_store, {
        host: redis_host,
        port: redis_port,
        db: 0,
        namespace: "_#{Rails.application.class.parent_name.downcase}_cache",
        expires_in: 30.days
      }
    end

    config.action_dispatch.default_headers = { 'X-Frame-Options' => 'ALLOWALL' }
  end
end
