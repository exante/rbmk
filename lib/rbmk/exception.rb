class Exception

	def log
		$log.error sprintf('%s: %s (%s)', backtrace.first, message, self.class)
	end

	def log_debug
		$log.debug sprintf('%i: %s (%s)', to_i, message, self.class)
	end

end
