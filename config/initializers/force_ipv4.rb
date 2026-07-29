# config/initializers/force_ipv4.rb
require 'socket'

original_getaddrinfo = Socket.method(:getaddrinfo)
Socket.define_singleton_method(:getaddrinfo) do |*args|
  args[2] = Socket::AF_INET
  original_getaddrinfo.call(*args)
end

class TCPSocket
  class << self
    alias_method :original_open, :open
  end

  def self.open(host, *rest)
    ip = Socket.getaddrinfo(host, nil, Socket::AF_INET).first[3]
    original_open(ip, *rest)
  rescue SocketError
    original_open(host, *rest) # fall back if no A record exists
  end
end