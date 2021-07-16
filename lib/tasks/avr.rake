namespace :avr do
  desc "Create SQS queues for shoryuken"
  task create_queues: :environment do
    Dir['app/jobs/**/*.rb'].each { |f| load f }
    sqs = Aws::SQS::Client.new

    queues = ActiveJob::Base.descendants.map do |job| 
      case job.queue_name
      when Proc then job.queue_name.call
      else job.queue_name
      end
    end.uniq

    queues.each do |queue_name|
      sqs.create_queue(queue_name: queue_name)
      $stderr.puts "Created #{queue_name}"
    end
  end
end
