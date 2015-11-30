#!/syntax/ruby
require File.expand_path('../lib/rbmk/version.rb', __FILE__)
Gem::Specification.new do |s|
	s.files = [
		'bin/rbmk',
		'examples/rbmk.rb',
		'lib/rbmk/exception.rb',
		'lib/rbmk/logger.rb',
		'lib/rbmk/operation.rb',
		'lib/rbmk/peer.rb',
		'lib/rbmk/server.rb',
		'lib/rbmk/upstream.rb',
		'lib/rbmk/version.rb',
		'lib/rbmk/worker.rb',
		'LICENSE',
		'README.md',
	]
	s.name = 'rbmk'
	s.summary = 'a trivial LDAP read-only proxy that allows you to get inside the bind and search operations'
	s.description = open(File.expand_path('../README.md', __FILE__)) { |fd| fd.read.match(/\[\/\/\]: # \(DESCRIPTION START\)(.*)\[\/\/\]: # \(DESCRIPTION STOP\)/m)[1].strip }
	s.version = RBMK::VERSION
	s.executables = [ 'rbmk' ]
	s.has_rdoc = false
	s.license = 'CC0'
	s.required_ruby_version = '>= 1.9.0'
	s.author = 'stronny red'
	s.email = 'stronny@celestia.ru'
	s.homepage = 'https://github.com/stronny/rbmk'
	s.add_dependency 'ruby-ldap', '~> 0.9.17'
	s.add_dependency 'ruby-ldapserver', '~> 0.5.3'
end
