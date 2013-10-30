class DropboxCallbacks
  def self.write_permissions_file(c, content)
    dropbox_dir = Avalon::Configuration.lookup('dropbox.path')
    perms_dir = File.expand_path('../.permissions', dropbox_dir)
    perms_file = File.join(perms_dir, c.dropbox_directory_name)
    File.open(perms_file,'w') { |f| f.puts content }
  end

  def self.after_save(c)
    adaptor = OmniAuth::LDAP::Adaptor.new Devise.omniauth_configs[:nuldap].strategy
    ldap = adaptor.connection
    grants = [c.managers,c.editors,c.depositors,RoleControls.users('administrator')].flatten.uniq
    members = grants.collect do |u|
      filter = Net::LDAP::Filter.eq("mail", u)
      result = ldap.search(filter: filter)
      result.empty? ? nil : result.first.uid.first
    end
    member_list = members.compact.join(' ')
    self.write_permissions_file(c, member_list)
  end

  def self.before_destroy(c)
    self.write_permissions_file(c, '*~DELETED~*')
  end
end

Admin::Collection.after_save DropboxCallbacks
Admin::Collection.before_destroy DropboxCallbacks
