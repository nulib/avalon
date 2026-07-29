# AVR: read course enrollments out of Canvas.
#
# Avalon's own LTI support gives a user exactly one virtual group -- the
# context_id of the launch they arrived through. AVR needs every course a user
# is currently enrolled in, so that a Northwestern SSO login (not just an LTI
# launch) grants access to that user's course reserves. Canvas' REST API is the
# only source for that, so User#virtual_groups asks here.
#
# Configured by Settings.canvas.api.{endpoint,token}. With no token configured
# every method no-ops, which is how development, test, and CI run.
class CanvasService
  class << self
    def client
      return @client if defined?(@client) && @client
      return nil if Settings.canvas&.api&.token.blank?

      @client = Faraday.new(Settings.canvas.api.endpoint).tap do |conn|
        conn.headers['Authorization'] = "Bearer #{Settings.canvas.api.token}"
      end
    end

    def find_course(code)
      return nil if client.nil?

      Rails.cache.fetch("CANVAS_COURSE_#{code}") do
        paged_results('api/v1/accounts/self/courses', search_term: code).find do |found_course|
          found_course['course_code'] == code
        end
      end
    end

    def find_user(net_id)
      return nil if client.nil?

      result = paged_results('api/v1/accounts/self/users', search_term: net_id)
      result.find { |entry| entry['login_id'] == net_id }&.fetch('id')
    end

    # => { <course_code> => <course name>, ... } for the user's active,
    # unexpired enrollments. Always a Hash, so callers can treat the result
    # uniformly whether or not the user exists in Canvas.
    def courses_for_user(net_id)
      user = find_user(net_id)
      return {} if user.nil?

      now = Time.now.utc
      active = paged_results("api/v1/users/#{user}/courses", enrollment_state: 'active').select do |course|
        course['end_at'].nil? || Time.parse(course['end_at']) >= now
      end
      active.to_h { |course| course.values_at('course_code', 'name') }
    end

    private

      def paged_results(path, params)
        page = 0
        [].tap do |result|
          loop do
            response = JSON.parse(client.get(path, params.merge(page: page += 1)).body)
            break if response.empty?

            result.concat(response)
          end
        end
      end
  end
end
