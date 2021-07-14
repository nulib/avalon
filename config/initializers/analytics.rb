begin
  require 'google-analytics-rails'
  GA.tracker = Settings.analytics_tracker
rescue LoadError
end