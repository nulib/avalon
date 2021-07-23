class MediaConvertEncode < WatchedEncode
  self.engine_adapter = :media_convert
  self.engine_adapter.queue = Settings&.encoding&.media_convert&.queue
  self.engine_adapter.role = Settings&.encoding&.media_convert&.role
  self.engine_adapter.output_bucket = Settings&.encoding&.derivative_bucket

  before_create prepend: true do |encode|
    encode.options.merge!({
      masterfile_bucket: Settings.encoding.masterfile_bucket,
      output_prefix: "#{options[:master_file_id]}/",
      use_original_url: true
    }).merge!(Settings.encoding.media_convert.configuration[:options][encode.options[:preset]])
  end

  reset_callbacks(:completed)
  after_completed prepend: true do |encode|
    map_outputs!(encode)
    record = ActiveEncode::EncodeRecord.find_by(global_id: encode.to_global_id.to_s)
    master_file = MasterFile.find(record.master_file_id)
    master_file.update_progress_on_success!(encode)
  end

  def map_outputs!(encode)
    Rails.logger.info("Mapping outputs for #{encode.to_global_id.to_s}")
    mapping = Settings.encoding.media_convert.configuration[:mapping]
    encode.output.collect! do |output|
      suffix = output.id.split('-').last
      output.label = mapping[suffix] || suffix
      output
    end
  end
end
