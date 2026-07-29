# AVR customization
require 'rails_helper'

describe GoogleTagManagerHelper, type: :helper do
  describe '.render_google_tag_manager' do
    around do |example|
      was = Settings.analytics_container_id
      Settings.analytics_container_id = container_id
      example.run
      Settings.analytics_container_id = was
    end

    context 'with a container id configured' do
      let(:container_id) { 'GTM-ABC1234' }

      it 'renders the container snippet' do
        expect(helper.render_google_tag_manager).to include('googletagmanager.com/gtm.js')
      end

      it 'quotes the container id as a JS string' do
        expect(helper.render_google_tag_manager).to include(%("#{container_id}"))
      end

      it 'is marked html_safe so the script is not escaped' do
        expect(helper.render_google_tag_manager).to be_html_safe
      end
    end

    context 'without a container id configured' do
      let(:container_id) { nil }

      it 'renders nothing' do
        expect(helper.render_google_tag_manager).to eq('')
      end
    end

    context 'with a blank container id' do
      let(:container_id) { '' }

      it 'renders nothing' do
        expect(helper.render_google_tag_manager).to eq('')
      end
    end
  end
end
