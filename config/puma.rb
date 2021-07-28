bind 'tcp://0.0.0.0:3000'
ssl_bind '0.0.0.0', '3001', 
  cert: ENV['SSL_CERT'],
  key: ENV['SSL_KEY']