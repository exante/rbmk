module Signal
	%w( CHLD INT HUP QUIT TERM ).each { |signame| const_set signame.to_sym, list[signame] }
end



require 'rbmk/peer'
module RBMK
class Server

	class Reaped < StandardError; end

	def initialize
		$master = true
		@arvg0 = File.basename Process.argv0
		@workers = {}
	end

	def start
		require 'socket'
		@upstream = self.class.upstream
		$log.debug sprintf('Listening on %s:%s', self.class.host, self.class.port)
		@socket = TCPServer.new self.class.host, self.class.port
		Signal.constants.each { |sig| Signal.trap Signal.const_get(sig), method(:trap) }
		$0 = sprintf '%s master at %s:%s', @arvg0, self.class.host, self.class.port
		loop { accept }
	ensure
		@socket.close rescue nil
		@workers.each { |pid| Process.kill 'TERM', pid rescue nil }
		Process.waitall rescue nil
		$log.debug 'Exiting'
	end

protected

	def self.host; '127.0.0.1' end
	def self.port; 8389 end

	def self.upstream
		require 'rbmk/upstream'
		RBMK::Upstream.new
	end

	def accept
		peer = Peer.new(client = @socket.accept)
		$log.info 'Connection from %s' % peer
		if pid = fork then
			client.close
			@workers[pid] = peer
		else
			$log.debug 'Worker started'
			act_as_a_child_for client, peer
		end
	rescue Reaped
		$log.debug $!.message
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
	rescue Errno::ECHILD
		# okay, nothing to do
	end

	def act_as_a_child_for client, peer
		Signal.trap 'CHLD', 'DEFAULT'
		$master = false
		remove_instance_variable :@workers
		$0 = sprintf '%s worker for %s', @arvg0, peer
		serve client
	rescue Exception
		$!.log
	ensure
		exit!
	end

	def serve client
		require 'rbmk/worker'
		Worker.hire client, @upstream
	end

end
end
