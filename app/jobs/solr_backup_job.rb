class SolrBackupJob < ActiveJob::Base
  queue_as Settings.active_job.queues.ingest

  def perform(location = '/data/backup')
    SolrCollectionAdmin.new.backup(location)
  end
end
