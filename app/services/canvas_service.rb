class CanvasService
  ALL_COURSES = 5000
  
  class << self
    def client
      if @client.nil? && Settings.canvas&.api&.token
        @client = Faraday.new(Settings.canvas.api.endpoint)
        @client.headers['Authorization'] = "Bearer #{Settings.canvas.api.token}"
      end
      @client
    end

    def find_course(code)
      return nil if client.nil?
      Rails.cache.fetch("CANVAS_COURSE_#{code}") do
        response = client.get('api/v1/accounts/self/courses', search_term: code, per_page: ALL_COURSES)
        result = JSON.parse(response.body)
        return nil if result.length.zero?
        result.first
      end
    end

    def find_user(net_id)
      return nil if client.nil?
      response = client.get('api/v1/accounts/self/users', search_term: net_id)
      result = JSON.parse(response.body)
      return nil if result.length.zero?
      result.first['id']
    end

    def courses_for_user(net_id)
      user = find_user(net_id)
      return [] if user.nil?
      response = client.get("api/v1/users/#{user}/courses", enrollment_state: 'active', per_page: ALL_COURSES)
      result = JSON.parse(response.body)
      Hash[result.collect { |course| course.values_at('course_code', 'name') }]
    end
  end
end
