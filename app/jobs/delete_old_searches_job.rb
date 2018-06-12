class DeleteOldSearchesJob < ApplicationJob
  def perform
    Search.where(['created_at < ? AND user_id IS NULL', 20.minutes.ago]).destroy_all
  end

end
