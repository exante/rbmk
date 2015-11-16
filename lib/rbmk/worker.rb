require 'ldap/server'
require 'rbmk/operation'
module RBMK
class Worker

	def self.hire client, upstream; new(client, upstream).serve end

	def initialize client, upstream
		@socket = client
		$log.debug 'Initializing'
		@conn = LDAP::Server::Connection.new @socket,
			server: upstream,
			logger: $log,
			operation_class: RBMK::Operation,
			schema: upstream.schema,
			namingContexts: upstream.root_dse['namingContexts']
	end

	def serve
		@conn.handle_requests
	rescue Terminated
		$log.info $!.message
	ensure
		@socket.close
		$log.debug 'Exiting'
	end

end
end
