class RBMK::Upstream
	require 'net/ldap'

	attr_reader :ldap, :root_dse, :schema
	def initialize host, port
		@schema = LDAP::Server::Schema.new
		@ldap = Net::LDAP.new host: host, port: port
		@ldap.bind
		@root_dse = fetch ''
		sse = fetch root_dse['subschemaSubentry'].first
		sse['attributeTypes'].each { |at| @schema.add_attrtype    at unless at.start_with? '( 1.3.6.1.4.1.4203.1.12.2' }
		sse['objectClasses'].each  { |oc| @schema.add_objectclass oc unless oc.start_with? '( 1.3.6.1.4.1.4203.1.12.2' }
		@schema.add_attrtype '( 2.5.18.6 NAME \'subtreeSpecification\' SYNTAX 1.3.6.1.4.1.1466.115.121.1.45 SINGLE-VALUE USAGE directoryOperation )'
		@schema.add_attrtype '( 2.5.21.1 NAME \'dITStructureRules\' EQUALITY integerFirstComponentMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.17 USAGE directoryOperation )'
		@schema.add_attrtype '( 2.5.21.7 NAME \'nameForms\' EQUALITY objectIdentifierFirstComponentMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.35 USAGE directoryOperation )'
		@schema.add_attrtype '( 2.5.21.2 NAME \'dITContentRules\' EQUALITY objectIdentifierFirstComponentMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.16 USAGE directoryOperation )'
		@schema.add_attrtype '( 1.3.6.1.4.1.4203.1.12.2.1 NAME \'configContext\' SYNTAX 1.3.6.1.4.1.1466.115.121.1.12 SINGLE-VALUE NO-USER-MODIFICATION USAGE dSAOperation )'
		@schema.resolve_oids
	end

protected

	def fetch dn
		entries = @ldap.search base: dn, scope: 0, attributes: ['*', '+'], ignore_server_caps: true
		entries.first
	end

end
