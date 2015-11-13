require 'logger'

require 'pp'

# ----------------------------------------------------------
# Error propagation facilities
#
class LDAP::ResultError

	@map = []
	constants.each do |const|
		c = const_get const
		i = c.new.send :to_i rescue nil
		@map[i] = c if i
	end

	def self.from_id id, msg
		@map[id].new msg
	end

end

# ----------------------------------------------------------
# Raw ASN.1 filter management
#
class Net::LDAP::Filter
	class Raw < self
		class << self
			public :new # ain't no java here
		end

		def initialize filter
			@filter = filter
		end

		def to_ber
			@filter.to_der
		end
	end
end

# ----------------------------------------------------------
# Seriously poor design on their part
#
class Net::LDAP
	remove_const :Entry
	class Entry < ::Hash

		attr_reader :dn
		def initialize dn = nil
			super
			@dn = dn
		end

		def inspect
			sprintf 'LDAP %s: %s', @dn, super
		end

	end
end

#
#
#
module Signal
	%w( CHLD INT HUP QUIT TERM ).each { |signame| const_set signame.to_sym, list[signame] }
end

module RBMK
	VERSION = '0.1.0'

	class Peer
		def initialize client
			@host = client.peeraddr[3]
			@port = client.peeraddr[1]
		end

		def to_s
			sprintf '%s:%s', @host, @port
		end
	end

end
