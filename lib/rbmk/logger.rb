module RBMK
module Logger

	def self.level; ::Logger::INFO end

	def self.format lvl, ts, prog, msg
		sprintf '%s %s [%s] %s', ts.strftime('%F:%T'), lvl, ($master ? 'M' : 'w'), msg
	end

	def self.instance
		require 'logger'
		log = ::Logger.new STDERR
		log.level = level
		log.formatter = self.class.method :format
		log
	end

end
end
