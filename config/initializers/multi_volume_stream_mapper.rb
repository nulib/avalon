require 'avalon/stream_mapper'

Avalon::StreamMapper = Class.new do
  attr_accessor :streaming_server, :location_map
  
  def initialize
    @streaming_server = Avalon::Configuration.lookup('streaming.server')
    @handler_config = YAML.load(File.read(Rails.root.join('config/url_handlers.yml')))
    @location_map = YAML.load(File.read(Rails.root.join('config/streaming_location_map.yml')))
  end
  
  def url_handler
    @handler_config[self.streaming_server.to_s]
  end

  def base_path_for(path)
    result = location_map.keys.find { |base_path| path.start_with?(base_path) }
    raise ArgumentError, "No streaming path prefix defined for `#{path}'" if result.nil?
    result
  end
  
  def base_url_for(path, protocol)
    location_map[base_path_for(path)]["#{protocol}_base"]
  end

  def stream_details_for(path)
    content_path = Pathname.new(base_path_for(path))
    p = Pathname.new(path).relative_path_from(content_path)
    Avalon::DefaultStreamMapper::Detail.new(base_url_for(path,'rtmp'),base_url_for(path,'http'),p.dirname,p.basename(p.extname),p.extname[1..-1])
  end

  def map(path, protocol, format)
    template = ERB.new(self.url_handler[protocol][format])
    template.result(stream_details_for(path).get_binding)
  end
end.new
