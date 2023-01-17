require 'rails_helper'

describe GoogleTagManagerHelper, type: :helper do
  context 'with analytics configured' do
    before do
      @analytics_container_id = Settings.analytics_container_id
      Settings.analytics_container_id = container_id
    end
    after do
      Settings.analytics_container_id = @analytics_container_id
    end

    let(:container_id) { 'arandomid' }

    describe '.render_google_tag_manager_head' do
      it("renders the script") do
        expect(helper.render_google_tag_manager_head).to include(container_id)
      end
    end

    describe '.render_google_tag_manager_body' do
      it("renders the noscript tag") do
        expect(helper.render_google_tag_manager_head).to include(container_id)
      end
    end
  end

  context 'without analytics configured' do
    describe '.render_google_tag_manager_head' do
      it('returns an empty string') do
        expect(helper.render_google_tag_manager_head).to eq('')
      end
    end

    describe '.render_google_tag_manager_body' do
      it('returns an empty string') do
        expect(helper.render_google_tag_manager_body).to eq('')
      end
    end
  end
end
