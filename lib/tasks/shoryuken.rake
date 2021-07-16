# ActiveJob and ActionMailer handle queue names and prefixes differently, so
# we need to make allowances for the fact that ActiveJob queue names will
# already have their prefixes while ActionMailer queue names will not

namespace :shoryuken do
  desc "Create shoryuken config file"
  task create_config: :environment do
    Rails.root.glob('app/jobs/**/*').each { |file| load file }
    active_job_config = Rails.application.config.active_job
    prefix = active_job_config.queue_name_prefix.to_s + active_job_config.queue_name_delimiter.to_s
    queue_names = ActiveJob::Base.descendants.collect do |job_class|
      queue_name = job_class.queue_name || 'default'
      queue_name = queue_name.call if queue_name.respond_to?(:call)
      queue_name = 'default' if queue_name.nil?
      queue_name = prefix + queue_name unless queue_name.start_with?(prefix)
      queue_name
    end.uniq
    template = ERB.new(File.read(Rails.root.join('config/shoryuken.yml.erb')), trim_mode: '<>')
    File.open(Rails.root.join('config/shoryuken.yml'), 'w') do |config_file|
      rendered = template.result(binding)
      config_file.write(rendered)
    end
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