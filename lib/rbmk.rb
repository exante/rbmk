module RBMK

	def self.context
		@context ||= {}
	end

	# Patch this method to hack incoming bind data
	#
	def self.hack_simple_bind data
#		version, dn, password = data
		data
	end

	# Patch this method to hack incoming search filters
	#
	def self.hack_filter filter
		filter
	end

	# Patch this method to hack outbound found entries
	#
	def self.hack_entries entries
		entries
	end

end
