#require 'net/ldap/filter'
require 'ldap/server/operation'

# class Net::LDAP::Filter
# 	class Raw < self
# 		class << self
# 			public :new # ain't no java here
# 		end
# 		def initialize filter; @filter = filter end
# 		def to_ber; @filter.to_der end
# 	end
# end
# 
# class Net::LDAP
# 	remove_const :Entry
# 	class Entry < ::Hash
# 		attr_reader :dn
# 		def initialize dn = nil
# 			super
# 			@dn = dn
# 		end
# 		def inspect; sprintf 'LDAP %s: %s', @dn, super end
# 	end
# end

class LDAP::ResultError
	@map = []
	constants.each do |const|
		c = const_get const
		i = c.new.send :to_i rescue nil
		@map[i] = c if i
	end

	def self.from_id id, msg = nil
		@map[id].new msg
	end
end



module RBMK
class Operation < LDAP::Server::Operation

	def ldap; @server.ldap end

	def simple_bind version, dn, password
		debug "Bind v#{version.to_i}, dn: #{dn.inspect}"
		@server.bind version, dn, password
	rescue LDAP::ResultError
		$!.log_debug
		raise $!
	end

	def send_SearchResultEntry(dn, avs, opt={})
		@rescount += 1
		if @sizelimit
			raise LDAP::ResultError::SizeLimitExceeded if @rescount > @sizelimit
		end

		if @schema
			@attributes = @attributes.map { |a| (['*', '+'].include? a) ? a : @schema.find_attrtype(a).to_s }
		end

		avseq = []

		avs.each do |attr, vals|

			send = if @attributes.include? '+' then
				true
			elsif @attributes.include? '*' then
				if @schema then
					a = @schema.find_attrtype(attr) rescue nil
					a and (a.usage.nil? or a.usage == :userApplications)
				else
					true
				end
			else
				@attributes.include? attr
			end

			next unless send

			if @typesOnly
				vals = []
			else
				vals = [vals] unless vals.kind_of?(Array)
			end
			avseq << OpenSSL::ASN1::Sequence([OpenSSL::ASN1::OctetString(attr), OpenSSL::ASN1::Set(vals.collect { |v| OpenSSL::ASN1::OctetString(v.to_s) })])
		end

		send_LDAPMessage(OpenSSL::ASN1::Sequence([OpenSSL::ASN1::OctetString(dn), OpenSSL::ASN1::Sequence(avseq)], 4, :IMPLICIT, :APPLICATION), opt)
	end

	def do_search op, controls
#		@raw_filter = Net::LDAP::Filter::Raw.new op.value[6]
		baseObject = op.value[0].value
		scope = op.value[1].value
		deref = op.value[2].value
		client_sizelimit = op.value[3].value
		client_timelimit = op.value[4].value.to_i
		@typesOnly = op.value[5].value
		filter = LDAP::Server::Filter.parse(op.value[6], @schema)
		@attributes = op.value[7].value.collect {|x| x.value}
#		debug "Search #{filter.inspect} from \"#{baseObject}\", scope: #{scope.to_i}, deref: #{deref.to_i}, attrs: #{@attributes.inspect}, no_values: #{@typesOnly}, max: #{@sizelimit.inspect}"

#		fil = Net::LDAP::Filter.parse_ber(@raw_filter.to_ber.read_ber).to_raw_rfc2254
#		debug "Search #{fil} from \"#{baseObject}\", scope: #{scope.to_i}, deref: #{deref.to_i}, attrs: #{@attributes.inspect}, no_values: #{@typesOnly}, max: #{@sizelimit.inspect}"

		@rescount = 0
		@sizelimit = server_sizelimit
		@sizelimit = client_sizelimit if client_sizelimit > 0 and (@sizelimit.nil? or client_sizelimit < @sizelimit)

		if baseObject.empty? and scope == LDAP::Server::BaseObject
			send_SearchResultEntry("", @server.root_dse) if @server.root_dse and LDAP::Server::Filter.run(filter, @server.root_dse)
			send_SearchResultDone(0)
			return
		elsif @schema and baseObject == @schema.subschema_dn
			send_SearchResultEntry(baseObject, @schema.subschema_subentry) if @schema and @schema.subschema_subentry and LDAP::Server::Filter.run(filter, @schema.subschema_subentry)
			send_SearchResultDone(0)
			return
		end

		t = server_timelimit || 10
		t = client_timelimit if client_timelimit > 0 and client_timelimit < t

		Timeout::timeout(t, LDAP::ResultError::TimeLimitExceeded) { search baseObject, scope, deref, filter }
		send_SearchResultDone(0)

 	rescue LDAP::Abandon
	rescue LDAP::ResultError => e
		log e.message
		send_SearchResultDone(e.to_i, :errorMessage=>e.message)
	rescue Exception => e
		log_exception(e)
		send_SearchResultDone(LDAP::ResultError::OperationsError.new.to_i, :errorMessage=>e.message)
	end

	def search basedn, scope, deref, filter
		entries = @ldap.search base: basedn, filter: @raw_filter, scope: scope.to_i, deref: deref.to_i, attributes: ['*', '+'], size: @sizelimit.to_i
#pp entries
		check_upstream
		transformed(entries).each { |entry| send_SearchResultEntry entry.dn, entry }
	end

	def compare entry, attr, val
		p compare: [entry, attr, val]
		super entry, attr, val
	end

protected

	def transformed entries
		return entries unless RBMK.respond_to? :transform
		RBMK.transform entries
	rescue
		@connection.log_exception $!
		entries
	end

end
end
