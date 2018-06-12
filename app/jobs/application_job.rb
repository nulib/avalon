class ApplicationJob < ActiveJob::Base
  queue_as Settings.active_job.queues.ingest
end
