config = Rails.application.config

redis_host = Settings.redis.host
redis_port = Settings.redis.port || 6379
redis_db = Settings.redis.db || 0

Redis.new(host: Settings.redis.host, port: Settings.redis.port).tap do |redis|
  (setting, value) = redis.config("GET", "replica-read-only")
  if value == "yes"
    redis.config("SET", "replica-read-only", "no")
  end
end

config.cache_store = :redis_store, {
  host: redis_host,
  port: redis_port,
  db: redis_db,
  namespace: 'avalon'
}


