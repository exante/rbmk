require 'net/ldap'
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

	def self.host; '127.0.0.1' end
	def self.port; 389 end

	attr_reader :ldap, :root_dse, :schema
	def initialize
		@schema = LDAP::Server::Schema.new
		(@ldap = Net::LDAP.new host: self.class.host, port: self.class.port).bind
		@root_dse = fetch ''
		SPECIAL_ATS.each { |name,at| @schema.add_attrtype format(name, at) }
		ssse = fetch @root_dse['subschemaSubentry'].first
		{add_attrtype: 'attributeTypes', add_objectclass: 'objectClasses'}.each { |meth,id| ssse[id].each { |str| @schema.send meth, str unless str.start_with? FILTER_PREFIX } }
		@schema.resolve_oids
	end

	def fetch dn; (@ldap.search base: dn, scope: 0, attributes: ['*', '+'], ignore_server_caps: true).first end

	protected def format name, at
		sprintf '( %s NAME \'%s\'%s SYNTAX 1.3.6.1.4.1.1466.115.121.1.%s%s%s USAGE %s )', at[:oid], name,
			(at[:eq] ? " EQUALITY #{at[:eq]}": ''), at[:s], ((at[:f] and at[:f].include?('s')) ? ' SINGLE-VALUE' : ''),
			((at[:f] and at[:f].include?('u')) ? ' NO-USER-MODIFICATION' : ''), ((at[:f] and at[:f].include?('a')) ? 'dSAOperation' : 'directoryOperation')
	end

end
end
