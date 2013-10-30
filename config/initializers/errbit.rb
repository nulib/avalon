Airbrake.configure do |config|
  config.api_key = 'a5e854c57ce269fd25d920f1f0afe87f'
  config.host    = 'mbk-linux-dev.library.northwestern.edu'
  config.port    = 80
  config.secure  = config.port == 443
end
