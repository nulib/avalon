if File.exist?('/sys/hypervisor/uuid') && (File.read('/sys/hypervisor/uuid',3) == 'ec2')
  require 'aws-sdk-rails'
  Aws::Rails.add_action_mailer_delivery_method(:aws_sdk)
  ActionMailer::Base.delivery_method = :aws_sdk
  ActionMailer::Base.raise_delivery_errors = false
  ActionMailer::DeliveryJob.queue_as Settings.active_job.queues.ingest
end
