module RBMK
class Peer

	def initialize client
		@host = client.peeraddr[3]
		@port = client.peeraddr[1]
	end

	def to_s
		sprintf '%s:%s', @host, @port
	end

end
end
