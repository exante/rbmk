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
	def self.to_rfc preserved_filter
		raise ArgumentError, 'Array expected' unless preserved_filter.is_a? Array
		raise ArgumentError, 'Filter is empty' if preserved_filter.empty?
		filter = preserved_filter.clone
		op = filter.shift
		res = case op
			when :not then
				raise 'Empty subfilter' if (sf = send(__method__, filter)).empty?
				'!%s' % sf
			when :and then
				raise 'Empty subfilter' if (sf = filter.map { |f| send(__method__, f) }.join).empty?
				'&%s' % sf
			when :or
				raise 'Empty subfilter' if (sf = filter.map { |f| send(__method__, f) }.join).empty?
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



require 'rbmk/transform'
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


	# --------------------------------------------------------------------------
	# Okay, now the actual code
	#
	attr_reader :server, :orig, :transformed
	def initialize conn, mid
		super conn, mid
		@orig = {}
		@transformed = {}
	end

	def simple_bind version, dn, password
		orig = {version: version, dn: dn, password: password}
		opts = transformed __method__, orig.clone
		$log.info sprintf('Bind version: %s, dn: %s',
			log_chunk(orig, opts, '%i', :version),
			log_chunk(orig, opts, '%p', :dn)
		)
		@server.bind *opts.values_at(:version, :dn, :password)
	rescue LDAP::ResultError
		$!.log_debug
		raise $!
	end

	def search base, scope, deref, filter
		orig = {filter_array: filter, base: base, scope: scope, deref: deref, attrs: @attributes, vals: (not @typesOnly), limit: (@sizelimit.to_i rescue 0)}
		opts = transformed __method__, orig.clone
		orig[:filter_string] = LDAP::Server::Filter.to_rfc orig[:filter_array]
		opts[:filter_string] = LDAP::Server::Filter.to_rfc opts[:filter_array]
		$log.info sprintf('Search %s from %s, scope: %s, deref: %s, attrs: %s, vals: %s, limit: %s',
			log_chunk(orig, opts, '%p', :filter_string),
			log_chunk(orig, opts, '%p', :base),
			log_chunk(orig, opts, '%i', :scope),
			log_chunk(orig, opts, '%i', :deref),
			log_chunk(orig, opts, '%p', :attrs),
			log_chunk(orig, opts, '%s', :vals),
			log_chunk(orig, opts, '%i', :limit),
		)
		entries = @server.ldap.search_ext2(*opts.values_at(:base, :scope, :filter_string, :attrs), (not opts[:vals]), nil, nil, 0, 0, opts[:limit])
		transformed(:entries, entries).each { |entry| send_SearchResultEntry entry.delete('dn').first, entry }
	rescue LDAP::ResultError
		@server.handle_ldap_error
	end

protected

	def log_chunk orig, transformed, format, key
		if orig[key] === transformed[key] then
			sprintf format, orig[key]
		else
			sprintf "(#{format} -> #{format})", orig[key], transformed[key]
		end
	rescue
		debug "orig: #{orig.inspect}"
		debug "transformed: #{transformed.inspect}"
		debug "format: #{format.inspect}"
		debug "key: #{key.inspect}"
		raise $!
	end

	def transformed type, object
		@orig[type] = object
		@transformed[type] = RBMK::Transform.send type, object, self
	rescue
		$!.log
		object
	end

end
end
