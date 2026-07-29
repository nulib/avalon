# You also need to explicitly enable OAuth 1 support in the environment.rb or an initializer:
AUTH_10_SUPPORT = true

# AVR: Canvas sends its oauth_signature_method as "HMAC-SHA1" (uppercase),
# but the oauth gem registers its signature methods under lowercase keys and
# looks them up verbatim, so the launch fails to verify. Register an uppercase
# alias for each method rather than patching the gem.
OAuth::Signature.available_methods.keys.each do |method|
  OAuth::Signature.available_methods[method.upcase] = OAuth::Signature.available_methods[method]
end

module Avalon
  module Lti
    begin
      Configuration =
        YAML.load(ERB.new(File.read(File.expand_path('../../lti.yml', __FILE__))).result)
    rescue
      Configuration = {}
    end
  end
end
