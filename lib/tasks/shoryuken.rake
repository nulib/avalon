namespace :shoryuken do
  desc "Create shoryuken config file"
  task create_config: :environment do
    Rails.root.glob('app/jobs/**/*').each { |file| load file }
    queue_names = ActiveJob::Base.descendants.collect do |job_class|
      if job_class.queue_name.kind_of?(Proc)
        job_class.queue_name.call
      else
        job_class.queue_name
      end
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