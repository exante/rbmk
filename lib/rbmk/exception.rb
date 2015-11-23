class Exception

	def log
		$log.error sprintf('%s: %s (%s)', backtrace.first, message, self.class)
	end

	def log_debug
		$log.debug sprintf('%s: %s (%s)', (to_i rescue 'n/a'), message, self.class)
	end

end
