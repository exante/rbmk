require 'ldap/server'
require 'rbmk/operation'
module RBMK
class Worker

	def self.hire peer, upstream; new(peer, upstream).serve end

	def initialize peer, upstream
		upstream.mktemp
		@peer = peer
		@conn = LDAP::Server::Connection.new @peer.socket,
			server: upstream,
			logger: $log,
			operation_class: RBMK::Operation,
			schema: upstream.schema,
			namingContexts: upstream.root_dse['namingContexts']
	end

	def serve
		@conn.handle_requests
	ensure
		@peer.close
	end

end
end
