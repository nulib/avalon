# Copyright 2011-2026, The Trustees of Indiana University and Northwestern
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

# AVR: signs CloudFront stream URLs as well as cookies.
#
# Upstream only issues signed cookies, because its player always fetches
# playlists and segments through Avalon, which sets those cookies. AVR redirects
# the player straight at the pre-rendered playlist on CloudFront (see
# MasterFilesController#hls_manifest), so the URL itself has to carry a
# signature.
#
# Both signers come from aws-sdk-cloudfront rather than the cloudfront-signer
# gem upstream uses. cloudfront-signer configures a single process-wide signer
# via Aws::CF::Signer.configure, which can't be re-keyed and has no URL signing;
# Aws::CloudFront::{Url,Cookie}Signer are plain objects.
class SecurityService

  def rewrite_url(url, context)
    case Settings.streaming.server.to_sym
    when :aws
      context[:protocol] ||= :stream_hls
      uri = Addressable::URI.parse(url)
      case context[:protocol]
      when :stream_hls
        # Only encode spaces; all the built-in encoding methods will encode the slashes, which will break the URL.
        streaming_url = Addressable::URI.join(Settings.streaming.http_base, uri.path).to_s.gsub(' ', '%20')
        url_signer.signed_url(streaming_url, expires: expiration)
      else
        url
      end
    else
      session = context[:session] || { media_token: nil }
      token = context[:token] || StreamToken.find_or_create_session_token(session, context[:target])
      "#{url}?token=#{token}"
    end
  end

  def create_cookies(context)
    result = {}
    case Settings.streaming.server.to_sym
    when :aws
      domain = Addressable::URI.parse(Settings.streaming.http_base).host
      resource = "http*://#{domain}/#{context[:target]}/*"
      Rails.logger.info "Creating signed policy for resource #{resource}"
      expires = expiration
      # A wildcard resource needs an explicit policy; the signer only builds a
      # canned policy from a concrete URL.
      policy = {
        Statement: [{ Resource: resource, Condition: { DateLessThan: { "AWS:EpochTime": expires.to_i } } }]
      }.to_json
      cookie_signer.signed_cookie(resource, expires: expires, policy: policy).each_pair do |key, value|
        result[key] = {
          value: value,
          path: "/#{context[:target]}",
          domain: cookie_domain(context[:request_host], domain),
          expires: expires
        }
      end
    end
    result
  end

  private

    def expiration
      Settings.streaming.stream_token_ttl.to_f.minutes.from_now
    end

    # The widest domain that covers both the app and the streaming host, so one
    # cookie works for both.
    #
    # AVR: upstream intersects the two hosts' label sets, which is order- and
    # position-blind: for app host "avr.library.northwestern.edu" and stream host
    # "stream.avr.library.northwestern.edu" it yields "avr.library.northwestern.edu",
    # a domain the streaming host isn't under. Walking in from the TLD gives the
    # actual common suffix, "library.northwestern.edu".
    def cookie_domain(request_host, streaming_host)
      request_labels = request_host.to_s.split('.').reverse
      streaming_labels = streaming_host.to_s.split('.').reverse

      common = []
      streaming_labels.each_with_index do |label, index|
        break if request_labels[index] != label

        common << label
      end
      common.reverse.join('.')
    end

    def cookie_signer
      @cookie_signer ||= begin
        require 'aws-sdk-cloudfront'
        Aws::CloudFront::CookieSigner.new(
          key_pair_id: Settings.streaming.signing_key_id,
          private_key: Settings.streaming.signing_key
        )
      end
    end

    def url_signer
      @url_signer ||= begin
        require 'aws-sdk-cloudfront'
        Aws::CloudFront::UrlSigner.new(
          key_pair_id: Settings.streaming.signing_key_id,
          private_key: Settings.streaming.signing_key
        )
      end
    end

end
