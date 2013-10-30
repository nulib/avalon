require File.join(Rails.root,'app/models/user')
require 'net/ldap'

User.instance_eval do
  def self.find_for_lti(auth_hash, signed_in_resource=nil)
    class_id = auth_hash.extra.context_id
    if Course.find_by_context_id(class_id).nil?
      class_name = auth_hash.extra.context_name
      Course.create :context_id => class_id, :label => auth_hash.extra.consumer.context_label, :title => class_name unless class_name.nil?
    end
    uid = auth_hash.uid.sub(/^nu(\S{3}\d{3})$/,'\\1')
    result =
      User.find_by_username(uid) ||
      User.find_by_email(auth_hash.info.email) ||
      User.create(:username => uid, :email => auth_hash.info.email)
  end

  def self.find_for_nuldap(access_token, signed_in_resource=nil)
    username = access_token['extra']['raw_info']['uid'].first
    user = User.find_or_create_by_username(username) do |u|
      u.email = access_token.info['email']
    end
  end

  def self.autocomplete(query)
    adaptor = OmniAuth::LDAP::Adaptor.new Devise.omniauth_configs[:nuldap].strategy
    ldap = adaptor.connection
    filter = Net::LDAP::Filter.eq("mail", "#{query}*")
    result = ldap.search(filter: filter, attributes: ['mail'])
    result.collect { |r|
      email = r['mail'].first
      { id: email, display: email }
    }
  end
end
