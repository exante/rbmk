module MITM
class Operation < LDAP::Server::Operation

	def initialize conn, msgid
		super conn, msgid
		@ldap = @server.ldap
	end

	def check_upstream
		upstream = @ldap.get_operation_result
		return if upstream.code < 1
		debug 'Upstream: %s' % upstream.inspect
		raise LDAP::ResultError.from_id(upstream.code, upstream.message)
	end

	def simple_bind version, dn, password
		@ldap.auth dn, password if dn
		debug "Bind v.#{version.to_i}, auth: #{@ldap.instance_variable_get(:@auth).reject {|k|:password == k}.inspect}"
		result = @ldap.bind
		debug "Bind result: #{result}"
		check_upstream
		result
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
		@raw_filter = Net::LDAP::Filter::Raw.new op.value[6]
		baseObject = op.value[0].value
		scope = op.value[1].value
		deref = op.value[2].value
		client_sizelimit = op.value[3].value
		client_timelimit = op.value[4].value.to_i
		@typesOnly = op.value[5].value
		filter = LDAP::Server::Filter.parse(op.value[6], @schema)
		@attributes = op.value[7].value.collect {|x| x.value}
		debug "Search #{filter.inspect} from \"#{baseObject}\", scope: #{scope.to_i}, deref: #{deref.to_i}, attrs: #{@attributes.inspect}, no_values: #{@typesOnly}, max: #{@sizelimit.inspect}"

		@rescount = 0
		@sizelimit = server_sizelimit
		@sizelimit = client_sizelimit if client_sizelimit > 0 and (@sizelimit.nil? or client_sizelimit < @sizelimit)

		if baseObject.empty? and scope == LDAP::Server::BaseObject
			send_SearchResultEntry("", @server.root_dse) if @server.root_dse and LDAP::Server::Filter.run(filter, @server.root_dse)
			send_SearchResultDone(0)
			return
		elsif @schema and baseObject == @schema.subschema_dn
			end_SearchResultEntry(baseObject, @schema.subschema_subentry) if
			@schema and @schema.subschema_subentry and
			LDAP::Server::Filter.run(filter, @schema.subschema_subentry)
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
		return entries unless MITM.respond_to? :transform
		MITM.transform entries
	rescue
		@connection.log_exception $!
		entries
	end

end
end
