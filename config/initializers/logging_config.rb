# AVR: let the deployed log level be set from Settings (i.e. from an SSM
# parameter) without rebuilding the image. Rails' own config.log_level is read
# too early in boot for _aws_config.rb's SSM-sourced Settings to have landed.
Rails.logger.level = Settings.log_level.to_sym unless Settings.log_level.nil?
