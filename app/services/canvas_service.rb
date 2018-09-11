class CanvasService

  def initialize
    if Settings.canvas&.api&.token
      @client = Faraday.new(Settings.canvas.api.endpoint)
      @client.headers['Authorization'] = "Bearer #{Settings.canvas.api.token}"
    end
  end

  def find_user(net_id)
    return nil if @client.nil?
    response = @client.get('api/v1/accounts/self/users', search_term: net_id)
    result = JSON.parse(response.body)
    return nil if result.length.zero?
    result.first['id']
  end

  def courses_for_user(net_id)
    user = find_user(net_id)
    return [] if user.nil?
    response = @client.get("api/v1/users/#{user}/courses", enrollment_state: 'active')
    result = JSON.parse(response.body)
    Hash[result.collect { |course| course.values_at('course_code', 'name') }]
  end

end
