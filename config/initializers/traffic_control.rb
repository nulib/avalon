# This initializer depends on the cache_store initializer being run first and the cache store being redis
config = Rails.application.config.cache_store[1]
config.delete(:namespace)
ActiveJob::TrafficControl.client = Redis.new(config)

