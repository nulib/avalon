bind 'tcp://0.0.0.0:3000'
ssl_bind '0.0.0.0', '3001', 
  cert: File.join(ENV['HOME'], '.dev_cert', 'dev.rdc.cert.pem'),
  key: File.join(ENV['HOME'], '.dev_cert', 'dev.rdc.key.pem')