if File.exist?('/sys/hypervisor/uuid') && (File.read('/sys/hypervisor/uuid',3) == 'ec2')
  require 'aws-sdk-rails'
  require 'aws/rails/mailer'
  ActionMailer::Base.delivery_method = :aws_sdk
  ActionMailer::Base.raise_delivery_errors = false
end
