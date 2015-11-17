class Exception
	def log; $log.error sprintf('%s: %s (%s)', backtrace.first, message, self.class) end
end



module RBMK
module Logger

	def self.level; ::Logger::INFO end

	def self.format lvl, ts, prog, msg
		sprintf "%s [%s:%5i] %-5s %s\n", ts.strftime('%F:%T'), ($master ? 'M' : 'w'), Process.pid, lvl, msg
	end

	def self.instance
		require 'logger'
		log = ::Logger.new STDERR
		log.level = level
		log.formatter = method :format
		log
	end

end
end
