require 'timeout'
require 'rbmk/peer'
module RBMK
class Server

	%w( CHLD INT HUP QUIT TERM ).each { |sig| const_set ('SIG%s' % sig).to_sym, Signal.list[sig] }

	def initialize
		$master = true
		@arvg0 = File.basename Process.argv0
		@workers = {}
	end

	def start
		require 'rbmk/version'
		$log.info sprintf('rbmk version %s (codename %p) is warming up in an orange glow', VERSION, CODENAME)
		require 'socket'
		@upstream = self.class.upstream
		$log.debug sprintf('Listening on %s:%s', self.class.host, self.class.port)
		@socket = TCPServer.new self.class.host, self.class.port
		$0 = sprintf '%s master at %s:%s', @arvg0, self.class.host, self.class.port
		Signal.trap('CHLD') { raise SignalException, 'CHLD' }
		loop { accept }
	ensure
		@socket.close rescue nil
		$log.debug sprintf('Disposing of workers: %p', @workers.keys)
		Signal.trap('CHLD') {} # we'll bury them in synchronous fashion
		Thread.abort_on_exception = true
		@workers.each { |pid,_| Thread.new { kill pid } }
		sleep(0.1) while Thread.list.count > 1 # make sure everyone is dead
		$log.info 'Shutdown sequence complete'
	end

protected

	def self.host; '127.0.0.1' end
	def self.port; 8389 end
	def self.worker_timeout; 600 end # (in seconds) this is not per single request, this is for the whole session

	def self.upstream
		require 'rbmk/upstream'
		RBMK::Upstream.new
	end

	def accept
		peer = Peer.new @socket.accept
		$log.info 'Connection from %s' % peer
		if pid = fork then
			peer.close
			@workers[pid] = true
		else
			$log.debug 'Worker started'
			@socket.close
			act_as_a_child_for peer
		end
	rescue SignalException
		$log.debug 'Trapped %p' % ($!.signm.empty? ? 'SIGINT' : $!.signm)
		case $!.signo
			when SIGCHLD then reap
			when SIGINT, SIGHUP, SIGTERM then exit
			when SIGQUIT then
				$log.debug 'Committing emergency suicide'
				exit!
			else raise $!
		end
	end

	def act_as_a_child_for peer
		Signal.trap 'CHLD', 'SYSTEM_DEFAULT'
		$master = false
		remove_instance_variable :@workers
		$0 = sprintf '%s worker for %s', @arvg0, peer
		Timeout.timeout(self.class.worker_timeout) { serve peer } # FIXME shall move to master in the future or maybe drop altogether in favour of activity detection
	rescue SignalException
		$log.debug 'Trapped %p' % ($!.signm.empty? ? 'SIGINT' : $!.signm)
		raise $!
	rescue Exception
		$!.log
	ensure
		$log.debug 'Terminating'
		exit!
	end

	def serve peer
		require 'rbmk/worker'
		Worker.hire peer, @upstream
	end

	def kill pid
		$log.debug 'Killing worker %s' % pid
		Process.kill 'TERM', pid
		Process.wait pid
		$log.debug 'Worker %s will not be a problem anymore' % pid
	rescue Errno::ESRCH
		$log.debug 'Somehow worker %s was not alive' % pid
	rescue Errno::ECHILD
		$log.debug 'Worker %s has suddenly disappeared' % pid
	end

	def reap
		pid, status = Process.wait2 -1, Process::WNOHANG
		@workers.delete pid
		$log.debug 'Reaped %s' % pid
	rescue Errno::ECHILD
		$log.debug 'Something went wrong, no dead workers to reap'
	end

end
end
