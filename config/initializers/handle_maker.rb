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

  def create_handle(handle_id, url)
    begin
      handle = @conn.create_record(handle_id)
      handle.add(:URL, url)
      handle << Handle::Field::HSAdmin.new(@admin)
      result = handle.save
      logger.info "Created handle #{handle_id}"
      result
    rescue Handle::HandleError => err
      logger.error "Error creating handle #{handle_id}: #{err.message}"
    end
  end
  handle_asynchronously :create_handle

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
