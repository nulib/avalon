require 'rails_helper'

describe CreateAdaptivePlaylistJob do
  around do |example|
    Settings.encoding.derivative_bucket = 'streaming-test'
    Settings.streaming.server = 'aws'
    example.run
    Settings.reload!
  end
  
  let(:s3_bucket) { Aws::S3::Bucket.new(stub_responses: true, name: 'streaming-test') }
  let(:job) { CreateAdaptivePlaylistJob.new }
  let(:master_file) { FactoryBot.create(:master_file) }
  let(:derivatives) do
    ['low', 'medium', 'high'].map.with_index do |quality, index|
      url = "s3://#{Settings.encoding.derivative_bucket}/#{master_file.id}/quality-#{quality}/hls/video.m3u8"
      attrs = {
        master_file_id: master_file.id,
        location_url: url,
        hls_url: url,
        duration: 12875,
        track_id: "track-#{quality}",
        managed: false,
        quality: quality,
        audio_bitrate: 96000 + (16000 * index),
        audio_codec: "AAC",
        video_bitrate: 3500000 + (2250000 * index),
        video_codec: "H.264"
      }
      FactoryBot.create(:derivative, master_file_id: master_file.id).update_attributes(attrs)
    end
    master_file.reload
  end
  let(:auto_derivative) do
    url = "s3://#{Settings.encoding.derivative_bucket}/#{master_file.id}/video.m3u8"
    attrs = {
      location_url: url,
      hls_url: url,
      duration: 12875,
      track_id: "track-auto",
      managed: false,
      quality: 'auto'
    }
    FactoryBot.create(:derivative, master_file_id: master_file.id).update_attributes(attrs)
    master_file.reload
  end

  def auto_playlist(master_file)
    master_file.reload.derivatives.select { |d| d.quality == 'auto' }.first
  end

  describe "perform" do
    before do
      allow(Aws::S3::Bucket).to receive(:new).and_return(s3_bucket)
    end

    it 'skips if there are no derivatives' do
      expect(s3_bucket).not_to receive(:put_object)
      expect(auto_playlist(master_file)).to be_nil
      expect(job.perform(master_file.id)).to eq(false)
    end

    it 'creates an auto playlist' do
      derivatives
      expect(s3_bucket).to receive(:put_object).with(hash_including(key: "#{master_file.id}/video.m3u8"))
      expect(auto_playlist(master_file)).to be_nil
      expect(job.perform(master_file.id)).to eq(true)
      expect(auto_playlist(master_file)).to be_a(Derivative)
    end

    it 'skips if there is an existing auto playlist' do
      derivatives
      auto_derivative
      expect(s3_bucket).not_to receive(:put_object)
      expect(auto_playlist(master_file)).to be_a(Derivative)
      expect(job.perform(master_file.id)).to eq(false)
    end
  end
end
