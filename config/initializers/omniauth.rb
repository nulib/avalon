OmniAuth.configure do |config|
  config.allowed_request_methods << :get
  config.silence_get_warning = true
end