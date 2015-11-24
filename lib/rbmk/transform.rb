module RBMK
module Transform

	# Patch this method to transform incoming bind data.
	# Expect a hash with these keys:
	# :version              LDAP protocol version; should probably be 3
	# :dn                   Bind DN; like a "username"
	# :password             Cleartext! Verrrry sensitive!
	def self.simple_bind opts
		opts
	end

	# Patch this method to transform incoming search parameters.
	# Expect a hash with these keys:
	# :base                 Search base DN
	# :scope                0 is base, 1 is onelevel, 2 is subtree
	# :deref                whether to follow aliases (no time to explain, read more otherwhere)
	# :filter_array         IMPORTANT: this is a parsed filter from Ldap::Server as an array-tree
	# :attrs                Attributes to be included in resulting objects
	# :vals                 Whether to include values at all
	# :limit                Search will not return more than this amount of objects
	def self.search opts
		opts
	end

	# Patch this method to transform outbound found entries.
	# Expect an array of hashes, each of which MUST have a 'dn' key
	def self.found entries
		entries
	end

end
end
