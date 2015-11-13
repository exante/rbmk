		class Worker

			def initialize client, logger, upstream
				@log = logger
				@socket = client
				@log.debug '[W] Initializing'
				Sig.constants.each { |sig| Signal.trap Sig.const_get(sig), method(:trap) }
				@conn = LDAP::Server::Connection.new @socket,
					server: upstream,
					logger: @log,
					operation_class: MITM::Operation,
#					operation_args: [upstream],
					schema: upstream.schema,
					namingContexts: upstream.root_dse['namingContexts']
			end

			def trap sig
				raise Terminated.new('[W] Terminated on SIG%s' % Signal.signame(sig))
			end

			def serve!
				@conn.handle_requests
			rescue Terminated
				@log.info $!.message
			rescue
				@log.error $!
			ensure
				@socket.close
				@log.debug '[W] Exiting'
			end

		end
