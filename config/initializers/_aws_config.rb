# AVR: load Settings from AWS SSM Parameter Store.
#
# In AWS, AVR gets almost all of its configuration from SSM parameters under
# $SSM_PARAM_PATH/Settings (written by terraform/settings.tf) rather than from
# config/settings/*.yml. Parameter paths map onto nested Settings keys, e.g.
#
#   /avr/staging/Settings/streaming/http_base  ->  Settings.streaming.http_base
#
# The leading underscore in this filename is load-order significant: Rails
# loads config/initializers/*.rb in alphabetical order, and this has to run
# before any other initializer reads Settings. Don't rename it.
#
# Unset SSM_PARAM_PATH (development, test, CI) and this file does nothing.
return if ENV['SSM_PARAM_PATH'].blank?

require 'aws-sdk-ssm'

module AVR
  module SSMSettings
    class << self
      def parameter_hash(path)
        {}.tap do |result|
          each_parameter(path) { |param| place(result, param, path) }
        end
      end

      private

        def each_parameter(path)
          ssm = Aws::SSM::Client.new
          next_token = nil
          loop do
            response = ssm.get_parameters_by_path(
              path: path, recursive: true, with_decryption: true, next_token: next_token
            )
            response.parameters.each { |param| yield param }
            next_token = response.next_token
            break if next_token.nil?
          end
        end

        # Turn /<path>/a/b/c into hash[a][b][c].
        def place(hash, param, path)
          segments = param.name.split(%r{/})[path.split(%r{/}).length..-1]
          segments.reject!(&:empty?)
          key = segments.pop
          target = segments.inject(hash) { |h, segment| h[segment] ||= {} }
          target[key] = cast(param.value)
        end

        # SSM stores everything as a string; Settings consumers expect real types.
        def cast(value)
          case value
          when 'true' then true
          when 'false' then false
          else Integer(value) rescue Float(value) rescue value
          end
        end
    end
  end
end

Settings.add_source!(AVR::SSMSettings.parameter_hash("#{ENV['SSM_PARAM_PATH']}/Settings"))
Settings.reload!
