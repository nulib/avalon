Rails.application.config.session_store :redis_store,
                                       servers: ["redis://#{Settings.redis.host}:#{Settings.redis.port}/"],
                                       expires_in: 90.minutes,
                                       key: "_#{Rails.application.class.parent_name.downcase}_session"
