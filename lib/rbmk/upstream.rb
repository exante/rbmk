require 'tempfile'
require 'ldap'
require 'ldap/schema'
require 'ldap/server/schema'
module RBMK
class Upstream
	FILTER_PREFIX = '( 1.3.6.1.4.1.4203.1.12.2'
	SPECIAL_ATS = {
		subtreeSpecification: {s: 45, oid: '2.5.18.6', f: 's'},
		dITStructureRules:    {s: 17, oid: '2.5.21.1', eq: :integerFirstComponentMatch},
		dITContentRules:      {s: 16, oid: '2.5.21.2', eq: :objectIdentifierFirstComponentMatch},
		nameForms:            {s: 35, oid: '2.5.21.7', eq: :objectIdentifierFirstComponentMatch},
		configContext:        {s: 12, oid: '1.3.6.1.4.1.4203.1.12.2.1', f: 'sua'},
	}

	def self.search ldap, opts
		args = [
			opts.fetch(:base,        ''),
			opts.fetch(:scope,       LDAP::LDAP_SCOPE_SUBTREE),
			opts.fetch(:filter,      '(objectClass=*)'),
			opts.fetch(:attrs,       ['*', '+']),
			(not opts.fetch(:vals,   true)),
			opts.fetch(:serverctrls, nil),
			opts.fetch(:clientctrls, nil),
			opts.fetch(:sec,         0),
			opts.fetch(:usec,        0),
			opts.fetch(:s_attr,      0),
			opts.fetch(:s_proc,      ''),
		]
		res = ldap.search_ext2 *args
		res.each { |e| yield e } if block_given?
		res
	end

	attr_reader :ldap, :root_dse, :schema
	def initialize
		@schema = LDAP::Server::Schema.new
		SPECIAL_ATS.each { |name, at| @schema.add_attrtype format(name, at) }
		ldap = LDAP::Conn.new self.class.host, self.class.port
		ldap.set_option LDAP::LDAP_OPT_PROTOCOL_VERSION, 3
		ldap.bind do |ldap|
			@root_dse = ldap.root_dse.first
			ssse = ldap.schema
			{add_attrtype: 'attributeTypes', add_objectclass: 'objectClasses'}.each { |meth,id| ssse[id].each { |str| @schema.send meth, str unless str.start_with? FILTER_PREFIX } }
		end
		@schema.resolve_oids
		user_init
	end

	def bind version, dn, password
		@ldap = LDAP::Conn.new self.class.host, self.class.port
		@ldap.set_option LDAP::LDAP_OPT_PROTOCOL_VERSION, version.to_i
		dn ? @ldap.bind(dn, password) : @ldap.bind
	rescue LDAP::ResultError
		handle_ldap_error
	end

	def handle_ldap_error
		stderr = from_stderr { @ldap.perror 'LDAP' }                        # WHY U NO?
		message = stderr.match(/additional info:(.*)$/)[1].strip rescue nil # Seriously, how hard can it be to expose a server's message?
		raise LDAP::ResultError.from_id(@ldap.err, message)                 # FUCK ME WHY SHOULD I EVER PARSE MY OWN STDERR
	end

	def mktemp
		@temp = Tempfile.new 'rbmk'
		File.unlink @temp
	end

protected

	def self.host; '127.0.0.1' end
	def self.port; 389 end

	def format name, at
		sprintf '( %s NAME \'%s\'%s SYNTAX 1.3.6.1.4.1.1466.115.121.1.%s%s%s USAGE %s )', at[:oid], name,
			(at[:eq] ? " EQUALITY #{at[:eq]}": ''), at[:s], ((at[:f] and at[:f].include?('s')) ? ' SINGLE-VALUE' : ''),
			((at[:f] and at[:f].include?('u')) ? ' NO-USER-MODIFICATION' : ''), ((at[:f] and at[:f].include?('a')) ? 'dSAOperation' : 'directoryOperation')
	end

	def from_stderr
		saved = STDERR.dup
		STDERR.reopen @temp
		yield if block_given?
		STDERR.rewind
		STDERR.read
	ensure
		STDERR.reopen saved
		saved.close
	end

	# Patch this method to do something useful right after initialization
	def user_init; end

end
end
