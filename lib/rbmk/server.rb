module MITM
	class Server
		require 'socket'
		require 'ldap/server'
		require 'ldap/server/schema'

		class Terminated < StandardError; end

		class Reaped < StandardError; end

		def initialize host, port
			@arvg0 = File.basename Process.argv0
			@host = host
			@port = port
			@workers = {}
		end

		def start logger, upstream
			@log = logger
			@upstream = upstream
			@log.debug '[M] Initializing'
			@socket = TCPServer.new @host, @port
			oldsigs = {}
			Sig.constants.each { |sig| oldsigs[sig] = Signal.trap Sig.const_get(sig), method(:trap) }
			$0 = sprintf '%s master at %s:%s', @arvg0, @host, @port
			loop { accept }
		rescue Terminated
			@log.info $!.message
		rescue
			@log.error $!
		ensure
			@socket.close
			@workers.each { |pid| Process.kill 'TERM', pid rescue nil }
			Process.waitall rescue nil
			oldsigs.each { |sig, act| Signal.trap sig, act }
			@log.info '[M] Exiting'
		end

		def accept
			client = @socket.accept
			peer = Peer.new client
			@log.info '[M] Connection from %s' % peer
			if pid = fork then
				client.close
				@workers[pid] = peer
			else
				$0 = sprintf '%s worker for %s', @arvg0, peer
				Worker.new(client, @log, @upstream).serve!
				exit!
			end
		rescue Reaped
			@log.info $!.message
			retry
		end

		def trap sig = nil
			case sig
				when nil then raise 'Something went wrong, trapped a nil.'
				when Sig::CHLD then
					pid, status = Process.wait2 -1, Process::WNOHANG
					@workers.delete pid
					p status #DEBUG
					raise Reaped.new('[M] Reaped %s' % pid)
				else raise Terminated.new('[M] Terminated on SIG%s' % Signal.signame(sig))
			end
		end

		# ---------------------------------------------------------------
		# Serve the client
		#
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

		# ---------------------------------------------------------------
		# More sugar for the god of sugar
		#
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
end
