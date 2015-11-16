module Signal
	%w( CHLD INT HUP QUIT TERM ).each { |signame| const_set signame.to_sym, list[signame] }
end



require 'rbmk/peer'
module RBMK
class Server
	class Reaped < StandardError; end

	def self.host; '127.0.0.1' end
	def self.port; 8389 end

	def initialize
		@arvg0 = File.basename Process.argv0
		@workers = {}
	end

	def start upstream
		require 'socket'
		@upstream = upstream
		$log.debug 'Initializing'
		@socket = TCPServer.new self.class.host, self.class.port
		Signal.constants.each { |sig| Signal.trap Sig.const_get(sig), method(:trap) }
		$0 = sprintf '%s master at %s:%s', @arvg0, self.class.host, self.class.port
		$master = true
		loop { accept }
	ensure
		@socket.close
		@workers.each { |pid| Process.kill 'TERM', pid rescue nil }
		Process.waitall rescue nil
		$log.debug 'Exiting'
	end

	def accept
		peer = Peer.new(client = @socket.accept)
		$log.info 'Connection from %s' % peer
		if (pid = fork).nil? then
			Signal.trap 'CHLD', 'DEFAULT'
			$master = false
			@workers = nil
			$0 = sprintf '%s worker for %s', @arvg0, peer
			self.class.serve client, @upstream
			exit!
		end
		client.close
		@workers[pid] = peer
	rescue Reaped
		$log.info $!.message
		retry
	end

	def trap sig = nil
		case sig
			when nil then raise 'Something went wrong, trapped a nil.'
			when Signal::CHLD then
				pid, status = Process.wait2 -1, Process::WNOHANG
				@workers.delete pid
				raise Reaped.new('Reaped %s' % pid)
			else raise 'Terminated on SIG%s' % Signal.signame(sig)
		end
	end

	protected def serve client, upstream
		require 'rbmk/worker'
		Worker.hire client, upstream
	end

end
end
