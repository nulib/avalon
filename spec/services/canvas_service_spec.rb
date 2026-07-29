# AVR customization
describe CanvasService do
  before { described_class.instance_variable_set(:@client, nil) }
  after { described_class.instance_variable_set(:@client, nil) }

  context 'when Canvas is not configured' do
    before { allow(Settings).to receive(:canvas).and_return(nil) }

    it 'has no client' do
      expect(described_class.client).to be_nil
    end

    it 'returns an empty Hash of courses' do
      # Regression: this used to return [], and callers do .keys / .key? on it.
      expect(described_class.courses_for_user('abc123')).to eq({})
    end

    it 'finds no course or user' do
      expect(described_class.find_course('COMP_SCI 101')).to be_nil
      expect(described_class.find_user('abc123')).to be_nil
    end
  end

  context 'when Canvas is configured' do
    let(:endpoint) { 'https://canvas.example.edu/' }
    let(:settings) do
      Config::Options.new.merge!(api: { endpoint: endpoint, token: 'sekrit' })
    end

    before { allow(Settings).to receive(:canvas).and_return(settings) }

    it 'returns the courses a user is currently enrolled in' do
      stub_request(:get, "#{endpoint}api/v1/accounts/self/users")
        .with(query: hash_including(search_term: 'abc123'))
        .to_return({ body: [{ 'id' => 7, 'login_id' => 'abc123' }].to_json }, { body: '[]' })
      stub_request(:get, "#{endpoint}api/v1/users/7/courses")
        .to_return(
          { body: [
            { 'course_code' => 'COMP_SCI 101', 'name' => 'Intro', 'end_at' => nil },
            { 'course_code' => 'HIST 210', 'name' => 'Ancient', 'end_at' => 1.year.ago.iso8601 }
          ].to_json },
          { body: '[]' }
        )

      expect(described_class.courses_for_user('abc123')).to eq('COMP_SCI 101' => 'Intro')
    end

    it 'returns an empty Hash for a user Canvas does not know' do
      stub_request(:get, "#{endpoint}api/v1/accounts/self/users").to_return(body: '[]')

      expect(described_class.courses_for_user('nobody')).to eq({})
    end
  end
end
