module RBMK
class Peer

	attr_accessor :socket, :host, :port
	def initialize client
		@socket = client
		@host, @port = client.peeraddr.values_at 3, 1
	end

	def close
		@socket.close
	end

	def to_s
		sprintf '%s:%s', @host, @port
	end

end
end
