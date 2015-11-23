require 'ldap/server/operation'



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



class LDAP::Server::Filter
	def self.to_rfc filter
		raise ArgumentError, 'Array expected' unless filter.is_a? Array
		raise ArgumentError, 'Filter is empty' if filter.empty?
		op = filter.shift
		res = case op
			when :not then
				raise 'Empty subfilter' if (sf = to_rfc filter).empty?
				'!%s' % sf
			when :and then
				raise 'Empty subfilter' if (sf = filter.map { |f| to_rfc(f) }.join).empty?
				'&%s' % sf
			when :or
				raise 'Empty subfilter' if (sf = filter.map { |f| to_rfc(f) }.join).empty?
				'!%s' % sf

			when :true       then 'objectClass=*'
			when :false      then '!(objectClass=*)'
			when :undef      then raise 'Undefined filter has no RFC representation'

			when :present    then sprintf '%s=*',   filter.first
			when :eq         then sprintf '%s=%s',  filter.first, filter.last
			when :approx     then sprintf '%s~=%s', filter.first, filter.last
			when :ge         then sprintf '%s>=%s', filter.first, filter.last
			when :le         then sprintf '%s<=%s', filter.first, filter.last
			when :substrings then
				attr = filter.shift
				junk = filter.shift
				'%s=%s' % [attr, filter.join('*')]
			else raise 'Unknown op %s' % op.inspect
		end
		'(%s)' % res
	rescue
		$!.log_debug
		''
	end
end



require 'rbmk'
module RBMK
class Operation < LDAP::Server::Operation

	# First some patches
	#
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
		baseObject = op.value[0].value
		scope = op.value[1].value
		deref = op.value[2].value
		client_sizelimit = op.value[3].value
		client_timelimit = op.value[4].value.to_i
		@typesOnly = op.value[5].value
		filter = LDAP::Server::Filter.parse(op.value[6], @schema)
		@attributes = op.value[7].value.collect {|x| x.value}

		@rescount = 0
		@sizelimit = server_sizelimit
		@sizelimit = client_sizelimit if client_sizelimit > 0 and (@sizelimit.nil? or client_sizelimit < @sizelimit)

		if baseObject.empty? and scope == LDAP::Server::BaseObject
			send_SearchResultEntry('', @server.root_dse) if @server.root_dse and LDAP::Server::Filter.run(filter, @server.root_dse)
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



	# Okay, now the actual code
	#
	def simple_bind version, dn, password
		RBMK.context[:binddn] = {orig: dn}
		version, dn, password = transformed(simple_bind: [version, dn, password])
		RBMK.context[:binddn][:hacked] = dn
		$log.info sprintf('Bind v%i, dn: %p -> %p', version, RBMK.context[:binddn][:orig], RBMK.context[:binddn][:hacked])
		@server.bind version, dn, password
	rescue LDAP::ResultError
		$!.log_debug
		raise $!
	end

	def search basedn, scope, deref, filter
		RBMK.context[:filter] = {orig: filter, hacked: transformed(filter: filter)}
		filter = LDAP::Server::Filter.to_rfc RBMK.context[:filter][:hacked]
		$log.info sprintf('Search %p from %p, scope: %i, deref: %i, attrs: %p, no_values: %s, max: %i', filter, basedn, scope, deref, @attributes, @typesOnly, (@sizelimit.to_i rescue 0))
		entries = @server.ldap.search_ext2 basedn, scope, filter, ['*', '+'], @typesOnly, nil, nil, 0, 0, (@sizelimit.to_i rescue 0)
#require 'pp'
#pp entries
		transformed(entries: entries).each { |entry| send_SearchResultEntry entry.delete('dn').first, entry }
	rescue LDAP::ResultError
		@server.handle_ldap_error
	end

protected

	def transformed spec
		raise ArgumentError.new('Please provide a hash with exactly one key.') unless (spec.is_a? Hash) and (1 == spec.count)
		spec.each { |type, object| return RBMK.send "hack_#{type}".to_sym, object }
	rescue
		$!.log
		object
	end

end
end
