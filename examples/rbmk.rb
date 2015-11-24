# Override the host and port of the upstream LDAP server
#
class RBMK::Upstream
	def self.host; 'ldap.example.com' end
	def self.port; 33389 end
end

# Override the host and port of RBMK server
#
class RBMK::Server
	def self.host; '0.0.0.0' end
	def self.port; 10389 end
end

# Override logger settings
#
module RBMK::Logger
	def self.level; ::Logger::DEBUG end
end

# The magic! You can transform the LDAP operations
#
module RBMK::Transform

	# For example, we can add a fooBar attribute to any resulting object
	#
	def self.entries entries
		entries.map do |entry|
			entry.merge 'fooBar' => 'baz'
		end
	end

	# In this example we override atrributes in the request so that all of them are requested all the time
	#
	def self.search opts
		opts.merge attrs: ['*', '+']
	end

end
