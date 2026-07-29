# ActiveJob and ActionMailer handle queue names and prefixes differently, so
# we need to make allowances for the fact that ActiveJob queue names will
# already have their prefixes while ActionMailer queue names will not

require 'aws-sdk-sqs'

module AVR
  module ShoryukenQueues
    class << self
      # A job's queue_name is usually a String, but `queue_as { ... }` stores the
      # block itself, and ActiveJob instance_execs that block against a job
      # *instance* at enqueue time -- see ActiveJob::QueueName#queue_name. It
      # therefore can't be invoked from a rake task.
      #
      # ActionMailer::MailDeliveryJob is the case that matters: its block reads
      # `arguments`, which only exists on an instance, so calling it directly
      # raises
      #
      #   NameError: undefined local variable or method 'arguments'
      #             for class ActionMailer::MailDeliveryJob
      #
      # Calling it on a bare instance fails too, because `arguments.first` is nil
      # there and the block immediately calls .constantize on it.
      #
      # So resolve it the way ActiveJob does where that works, and otherwise fall
      # back to queue_name_from_part(nil) -- which is exactly what ActiveJob
      # substitutes in that case: the default queue name with the configured
      # prefix applied. That is where mail actually lands.
      def resolve(job_class)
        queue_name = job_class.queue_name
        return queue_name unless queue_name.is_a?(Proc)

        begin
          job_class.new.queue_name
        rescue StandardError
          job_class.queue_name_from_part(nil)
        end
      end

      def all
        active_job_config = Rails.application.config.active_job
        prefix = active_job_config.queue_name_prefix.to_s + active_job_config.queue_name_delimiter.to_s

        ActiveJob::Base.descendants.map { |job_class|
          queue_name = resolve(job_class)
          queue_name = 'default' if queue_name.blank?
          queue_name = prefix + queue_name unless queue_name.start_with?(prefix)
          queue_name
        }.uniq.sort
      end
    end
  end
end

namespace :shoryuken do
  desc "Create shoryuken config file"
  task create_config: :environment do
    Rails.root.glob('app/jobs/**/*').each { |file| load file }
    queue_names = AVR::ShoryukenQueues.all
    template = ERB.new(File.read(Rails.root.join('config/shoryuken.yml.erb')), trim_mode: '<>')
    File.open(Rails.root.join('config/shoryuken.yml'), 'w') do |config_file|
      rendered = template.result(binding)
      config_file.write(rendered)
    end
    $stderr.puts "Wrote config/shoryuken.yml with #{queue_names.length} queue(s): #{queue_names.join(', ')}"
  end

  desc "Create SQS queues for shoryuken"
  task create_queues: :environment do
    sqs = Aws::SQS::Client.new
    shoryuken_config = YAML.load(File.read(Rails.root.join('config/shoryuken.yml')))
    shoryuken_config["queues"].each do |queue_name, _count|
      sqs.create_queue(queue_name: queue_name)
      $stderr.puts "Created #{queue_name}"
    end
  end
end
