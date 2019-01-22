class CanvasService
  class << self
    def client
      if @client.nil? && Settings.canvas&.api&.token
        @client = Faraday.new(Settings.canvas.api.endpoint)
        @client.headers['Authorization'] = "Bearer #{Settings.canvas.api.token}"
      end
      @client
    end

    def paged_results(path, params)
      page = 0
      [].tap do |result|
        while true
          response = JSON.parse(client.get(path, params.merge(page: page+=1)).body)
          break if response.empty?
          result.concat(response)
        end
      end
    end

    def find_course(code)
      return nil if client.nil?
      Rails.cache.fetch("CANVAS_COURSE_#{code}") do
        result = paged_results('api/v1/accounts/self/courses', search_term: code)
        return nil if result.length.zero?
        result.first
      end
    end

    def find_user(net_id)
      return nil if client.nil?
      result = paged_results('api/v1/accounts/self/users', search_term: net_id)
      record = result.find { |entry| entry['login_id'] == net_id }
      record&.fetch('id')
    end

    def courses_for_user(net_id)
      user = find_user(net_id)
      return [] if user.nil?
      result = paged_results("api/v1/users/#{user}/courses", enrollment_state: 'active')
      Hash[result.collect { |course| course.values_at('course_code', 'name') }]
    end
  end
end
