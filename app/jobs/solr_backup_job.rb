class SolrBackupJob < ApplicationJob
  def perform(location = '/data/backup')
    SolrCollectionAdmin.new.backup(location)
  end
end
