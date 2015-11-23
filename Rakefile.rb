#spec = eval(open('gemspec') { |fd| fd.read })
specfn = 'gemspec'
spec = Gem::Specification.load specfn
gfn = sprintf('%s-%s.gem', spec.name, spec.version)

file gfn => spec.files + [specfn] do
	require 'rubygems'
	require 'rubygems/package'
	Gem::Package.build spec
end

desc '(default) Build the gem: %s' % gfn
task build: gfn

desc 'Install a built gem'
task install: :build do
	require 'rubygems/dependency_installer'
	i = Gem::DependencyInstaller.new domain: :local, ignore_dependencies: true, prerelease: true, wrappers: false
	i.install gfn
end

task default: :build
