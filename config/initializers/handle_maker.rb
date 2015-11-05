require 'handle'

class HandleMaker
  include Loggable

  def initialize
    handle_params = YAML.load(File.read(File.join(Rails.root, 'config', 'handle_config.yml')))
    auth_params = handle_params[:auth].values_at(:handle, :index, :keyfile, :secret)
    @admin = handle_params[:owner]
    @conn = Handle::Connection.new(*auth_params)
    @prefix = handle_params[:prefix]
    @template = handle_params[:noid_template]
    @semaphore = Mutex.new
  end

  def admin_field
    result = Handle::Field::HSAdmin.new(@admin[:handle])
    if @admin.has_key?(:index)
      result.admin_index = @admin[:index]
    end
    result
  end
  
  def create_handle(handle_id, url)
    begin
      handle = @conn.create_record(handle_id)
      handle.add(:URL, url)
      handle << admin_field
      result = handle.save
      logger.info "Created handle #{handle_id}"
      result
    rescue Handle::HandleError => err
      logger.error "Error creating handle #{handle_id}: #{err.message}"
      Airbrake.notify err
    end
  end
 
  def verify_handle(obj)
    Rails.logger.info("Verifying handle for #{obj.inspect}")
    link = obj.permalink
    if link.present?
      url = begin
        Permalink.url_for(obj)
      rescue ArgumentError
        nil
      end
      unless url.nil?
        handle = link.split(/\//,4).last
        begin
          record = @conn.resolve_handle(handle)
          dirty = false
          url_field = record.find { |f| f.is_a?(Handle::Field::URL) }
          if url_field.nil?
            record.add(:URL, url)
            dirty = true
          elsif url_field.value != url
            url_field.value = url
            dirty = true
          end
          record.save if dirty
        rescue Handle::NotFound
          self.create_handle(handle, link)
        rescue Handle::HandleError => err
          logger.error "Error verifying handle: #{err.message}"
          Airbrake.notify err
        end
      end
      return true
    end
  end
  
  def unregister(obj)
    link = obj.permalink
    if link.present?
      handle = link.split(/\//,4).last
      if obj.is_a?(MediaObject)
        obj.descMetadata.permalink = nil
        obj.parts.each { |p| self.unregister(p) }
      end
      begin
        @conn.delete_handle(handle)
      rescue Handle::HandleError, Handle::NotFound
      end
      obj.permalink = nil
      obj.save(validate: false)
    end
  end

  def mint_id
    result = ''
    @semaphore.synchronize do
      File.open(File.join(Rails.root, 'config', 'minter_state.yml'), File::RDWR|File::CREAT, 0644) do |f|
        f.flock(File::LOCK_EX)
        yaml = YAML::load(f.read)
        yaml = {template: @template} unless yaml
        minter = ::Noid::Minter.new(yaml)
        result = minter.mint
        f.rewind
        yaml = YAML::dump(minter.dump)
        f.write yaml
        f.flush
        f.truncate(f.pos)
      end
    end
    return result
  end

  def permalink_for(obj,url)
    handle_id = "#{@prefix}#{mint_id}"
    create_handle(handle_id, url)
    logger.info "Minted handle #{handle_id} for #{url}"
    return "http://hdl.handle.net/#{handle_id}"
  end
end

Avalon::Permalink.on_generate do |obj,url|
  HandleMaker.new.permalink_for(obj,url)
end

MediaObject.after_save do |obj|
  HandleMaker.new.verify_handle(obj)
end

MasterFile.after_save do |obj|
  HandleMaker.new.verify_handle(obj)
end
