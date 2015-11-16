#spec = eval(open('gemspec') { |fd| fd.read })
spec = Gem::Specification.load 'gemspec'
gfn = sprintf('%s-%s.gem', spec.name, spec.version)

file gfn => spec.files do
	require 'rubygems'
	require 'rubygems/package'
	Gem::Package.build spec
end

desc '(default) Build the gem: %s' % gfn
task build: gfn

desc 'Install a built gem'
task install: :build do
	require 'rubygems/installer'
	i = Gem::Installer.new gfn, development: false, wrappers: false
	i.install
end

task default: :build
