require_relative 'boot'
require_relative '../lib/tempfile_factory'

require 'rails/all'
require 'resolv-replace'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Avalon
  VERSION = '8.2.0'

  class Application < Rails::Application
    require 'avalon/configuration'

    config.generators do |g|
      g.test_framework :rspec, :spec => true
    end

    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    # config.autoload_lib(ignore: %w[assets avalon capistrano tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # config.eager_load_paths << Rails.root.join("extras")

    # AVR: upstream hardcodes `:sidekiq` here. AVR runs its jobs on SQS via
    # Shoryuken, and queue names are namespaced per environment so that staging
    # and production can share an AWS account. All of it is driven from
    # Settings (i.e. from SSM in a deployed environment), so this file needs no
    # further AVR changes:
    #
    #   active_job:
    #     queue_adapter: shoryuken     # default: sidekiq
    #     queue_name_prefix: avr-staging
    #     queue_name_delimiter: '-'    # default: '-' when a prefix is set
    #     default_queue_name: default
    #
    # lib/tasks/shoryuken.rake reads the resulting queue names back out to
    # generate config/shoryuken.yml and to create the SQS queues.
    if Settings&.active_job&.queue_adapter.present?
      adapter = Settings.active_job.queue_adapter.to_s
      begin
        require adapter
      rescue LoadError
        # Adapters shipped with ActiveJob need no explicit require.
      end
      config.active_job.queue_adapter = adapter
    else
      config.active_job.queue_adapter = :sidekiq
    end

    config.active_job.queue_name_prefix = Settings&.active_job&.queue_name_prefix
    config.active_job.queue_name_delimiter =
      Settings&.active_job&.queue_name_delimiter ||
      (config.active_job.queue_name_prefix.present? ? '-' : nil)

    # ActiveJob::Base picks up queue_name_prefix; ActionMailer::Base does not,
    # so its queue name has to be set without the prefix.
    default_queue_name = Settings&.active_job&.default_queue_name || 'default'
    ActionMailer::Base.deliver_later_queue_name = default_queue_name
    ActiveJob::Base.queue_name = [
      config.active_job.queue_name_prefix,
      default_queue_name
    ].compact_blank.join(config.active_job.queue_name_delimiter.to_s)

    config.action_dispatch.default_headers = { 'X-Frame-Options' => 'ALLOWALL' }

    # We have a number of serializers in place that have not previously had a :coder defined.
    # Setting our global default to the old default :coder should maintain compatibility.
    config.active_record.default_column_serializer = YAML

    # Set active record encryption. Currently only used on user API tokens.
    config.active_record.encryption.primary_key = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"]
    config.active_record.encryption.deterministic_key = ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"]
    config.active_record.encryption.key_derivation_salt = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"]

    # Conditionally enable these for migration
    # ```ApiToken.all.each { |t| t.encrypt }```
    if ENV['ACTIVE_RECORD_ENCRYPTION_MIGRATION'] == 'true'
      config.active_record.encryption.support_unencrypted_data = true
      config.active_record.encryption.extend_queries = true
    end

    # Rails recommends having this set to false, especially in zeitwerk mode. However, that
    # currently causes issues with the Samvera gems (hydra-head, Blacklight)
    config.add_autoload_paths_to_load_path = true

    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins { |source| true }
        resource '/avalon_marker/*', headers: :any, credentials: true, methods: [:get, :post, :put, :delete]
        resource '/media_objects/*/manifest*', headers: :any, methods: [:get]
        resource '/master_files/*/thumbnail', headers: :any, methods: [:get]
        resource '/master_files/*/transcript/*', headers: :any, methods: [:get]
        resource '/master_files/*/structure.json', headers: :any, methods: [:get, :post, :delete]
        resource '/master_files/*/waveform.json', headers: :any, methods: [:get]
        resource '/master_files/*/*.m3u8', headers: :any, credentials: true, methods: [:get, :head]
        resource '/master_files/*/captions', headers: :any, methods: [:get]
        resource '/master_files/*/supplemental_files/*', headers: :any, methods: [:get]
        resource '/playlists/*/manifest*', headers: :any, credentials: true, methods: [:get]
        resource '/timelines/*/manifest*', headers: :any, methods: [:get, :post]
        resource '/master_files/*/search', headers: :any, methods: [:get]
        resource '/rails/active_storage/blobs/*/*/*', headers: :any, methods: [:get]
        resource '/rails/active_storage/disk/*/*', headers: :any, methods: [:get]
      end
    end

    config.middleware.insert_before 0, TempfileFactory

    # AVR: upstream lets Settings pick a service by name, but the services
    # themselves still have to be declared in config/storage.yml, which is baked
    # into the image. AVR needs the bucket and region to come from SSM at boot,
    # so allow Settings to contribute service definitions too, e.g.
    #
    #   active_storage:
    #     service: amazon
    #     service_configurations:
    #       amazon:
    #         service: S3
    #         bucket: avr-staging-uploads
    #         region: us-east-1
    if Settings&.active_storage&.service_configurations.present?
      configs = Settings.active_storage.service_configurations.to_hash
      if config.active_storage.service_configurations.is_a?(Hash)
        config.active_storage.service_configurations.merge!(configs)
      else
        config.active_storage.service_configurations = configs
      end
    end

    config.active_storage.service = (Settings&.active_storage&.service.presence || "local").to_sym
  end
end
