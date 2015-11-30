require 'ldap/server'
require 'rbmk/operation'
module RBMK
class Worker

	def self.hire peer, upstream; new(peer, upstream).serve end

	def initialize peer, upstream
		@upstream = upstream
		@upstream.mktemp
		@peer = peer
		@conn = LDAP::Server::Connection.new @peer.socket,
			server: @upstream,
			logger: $log,
			operation_class: RBMK::Operation,
			operation_args: [self],
			schema: @upstream.schema,
			namingContexts: @upstream.root_dse['namingContexts']
		user_init
	end

	def serve
		@conn.handle_requests
	ensure
		@peer.close
	end

protected

	# Patch this method to implement your additional worker init actions
	def user_init; end

end
end
