bind 'tcp://0.0.0.0:3000'
ssl_bind '0.0.0.0', '3001', 
  cert: File.join(ENV['HOME'], '.devbox_cert', 'devbox.library.full.pem'),
  key: File.join(ENV['HOME'], '.devbox_cert', 'devbox.library.key.pem')