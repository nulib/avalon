require 'aws-sdk-s3'

class CreateAdaptivePlaylistJob < ActiveJob::Base
  queue_as :create_adaptive_playlist

  def perform(master_file_id)
    master_file = MasterFile.find(master_file_id)
    return false if master_file.derivatives.count == 0

    playlist = adaptive_playlist(master_file)
    return false if playlist.nil?

    write_playlist(master_file, playlist)
    update_derivatives(master_file)
  end

  private

  def key_for(master_file)
    Addressable::URI.new(scheme: 's3', host: Settings.encoding.derivative_bucket, path: master_file.id + '/')
  end

  def adaptive_playlist(master_file)
    key = key_for(master_file)
    streams = master_file.hls_streams.select { |hls| hls[:url].start_with?(key) }
    return nil if streams.find { |hls| hls[:quality] == 'auto' }

    StringIO.new.tap do |result|
      result.puts('#EXTM3U')
      streams.each do |hls|
        result.puts("#EXT-X-STREAM-INF:BANDWIDTH=#{hls[:bitrate]}")
        result.puts(hls[:url].split(master_file.id).last.sub(/^\/+/, ''))
      end
    end.string
  end

  def basename(master_file)
    original_file = master_file.file_location
    File.basename(original_file, File.extname(original_file)) + '.m3u8'
  end

  def write_playlist(master_file, playlist)
    digest = Digest::MD5.new << playlist
    bucket = Aws::S3::Bucket.new(name: Settings.encoding.derivative_bucket)
    key = File.join(master_file.id, basename(master_file))
    bucket.put_object(
      key: key, 
      acl: 'private', 
      content_md5: digest.base64digest,
      content_type: 'application/x-mpegURL', 
      body: playlist
    )
  end

  def update_derivatives(master_file)
    url = key_for(master_file).join(master_file.id).join(basename(master_file)).to_s

    derivative = master_file.derivatives.select { |d| d.quality == 'auto' }.first
    derivative ||= Derivative.create(master_file: master_file, quality: 'auto')
    derivative.audio_codec = master_file.derivatives.first.audio_codec
    derivative.video_codec = master_file.derivatives.first.video_codec
    derivative.location_url = derivative.hls_url = derivative.derivativeFile = url
    derivative.save
  end
end
