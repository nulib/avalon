config = Rails.application.config

redis_host = Settings.redis.host
redis_port = Settings.redis.port || 6379

begin
  Redis.new(host: Settings.redis.host, port: Settings.redis.port).tap do |redis|
    (setting, value) = redis.config("GET", "replica-read-only")
    if value == "yes"
      redis.config("SET", "replica-read-only", "no")
    end
  end
rescue Redis::CannotConnectError, Redis::CommandError
  # Don't worry about it
end

config.cache_store = :redis_store, {
  host: redis_host,
  port: redis_port,
  db: 0,
  namespace: 'avalon'
}
