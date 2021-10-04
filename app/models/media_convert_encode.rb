require 'aws-sdk-lambda'

class MediaConvertEncode < WatchedEncode
  self.engine_adapter = :media_convert
  self.engine_adapter.queue = Settings&.encoding&.media_convert&.queue
  self.engine_adapter.role = Settings&.encoding&.media_convert&.role
  self.engine_adapter.output_bucket = Settings&.encoding&.derivative_bucket

  before_create prepend: true do |encode|
    if encode.input.url =~ %r{s3://(.+?)/(.+)\.aiff$}
      wav_url = "s3://#{$1}/wav_temp/#{$2}.wav"
      Honeybadger.notify(
        "AIFF file found. Invoking aiff2wav.", 
        class_name: "MediaConvertEncode", 
        tags: "encoding", 
        context: {
          input_url: encode.input.url,
          master_file_id: encode.options[:master_file_id]
        }
      )
      Rails.logger.warn("#{encode.input.url} is AIFF. Creating intermediate WAV file #{wav_url}.")
      lambda_client = Aws::Lambda::Client.new
      payload = { source: encode.input.url, dest: wav_url }
      lambda_client.invoke(function_name: Settings.encoding.aiff_lambda, payload: payload.to_json)
      encode.input.url = wav_url
    end
    
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
    if encode.input.url =~ %r{/wav_temp/}
      Rails.logger.warn("Deleting intermediate WAV file #{encode.input.url}")
      FileLocator::S3File.new(encode.input.url).object.delete
    end
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
