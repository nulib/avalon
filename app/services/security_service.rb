# Copyright 2011-2020, The Trustees of Indiana University and Northwestern
#   University.  Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed
#   under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
#   CONDITIONS OF ANY KIND, either express or implied. See the License for the
#   specific language governing permissions and limitations under the License.
# ---  END LICENSE_HEADER BLOCK  ---

class SecurityService

  def rewrite_url(url, context)
    case Settings.streaming.server.to_sym
    when :aws
      context[:protocol] ||= :stream_hls
      uri = Addressable::URI.parse(url)
      expiration = Settings.streaming.stream_token_ttl.to_f.minutes.from_now
      case context[:protocol]
      when :stream_hls
        streaming_url = URI.encode(Addressable::URI.join(Settings.streaming.http_base,uri.path).to_s)
        url_signer.signed_url(streaming_url, expires: expiration)
      else
        url
      end
    else
      session = context[:session] || { media_token: nil }
      token = StreamToken.find_or_create_session_token(session, context[:target])
      "#{url}?token=#{token}"
    end
  end

  def create_cookies(context)
    result = {}
    case Settings.streaming.server.to_sym
    when :aws
      domain = Addressable::URI.parse(Settings.streaming.http_base).host
      domain_segments = domain.split(/\./).reverse
      stream_segments = context[:request_host].split(/\./).reverse
      cookie_domain_segments = []
      domain_segments.each.with_index do |segment, index|
        break if stream_segments[index] != segment
        cookie_domain_segments << segment
      end
      cookie_domain = cookie_domain_segments.reverse.join('.')
      resource = "http*://#{domain}/#{context[:target]}/*"
      Rails.logger.info "Creating signed policy for resource #{resource}"
      expiration = Settings.streaming.stream_token_ttl.to_f.minutes.from_now
      policy = { Statement: [ { Resource: resource, Condition: { DateLessThan: { "AWS:EpochTime": expiration.to_i } } } ] }.to_json
      cookie_signer.signed_cookie(resource, expires: expiration, policy: policy).each_pair do |key, value|
        result[key] = {
          value: value,
          path: "/#{context[:target]}",
          domain: cookie_domain,
          expires: expiration
        }
      end
    end
    result
  end

  private
    def cookie_signer
      if @cookie_signer.nil?
        require 'aws-sdk-cloudfront'
        @cookie_signer = Aws::CloudFront::CookieSigner.new(key_pair_id: Settings.streaming.signing_key_id, private_key: Settings.streaming.signing_key)
      end
      @cookie_signer
    end

    def url_signer
      if @url_signer.nil?
        require 'aws-sdk-cloudfront'
        @url_signer = Aws::CloudFront::UrlSigner.new(key_pair_id: Settings.streaming.signing_key_id, private_key: Settings.streaming.signing_key)
      end
      @url_signer
    end
end
