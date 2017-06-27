if ENV['REDIS_HOST']
  Avalon::Application.config.session_store :redis_store, {
    servers: [
      {
        host: ENV['REDIS_HOST'],
        port: ENV['REDIS_PORT'] || 6379,
        db: 0,
        namespace: 'avalon'
      },
    ],
    expire_after: 90.minutes
  }
else
  Avalon::Application.config.session_store :active_record_store
end
