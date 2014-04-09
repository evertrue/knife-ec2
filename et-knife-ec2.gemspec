# -*- encoding: utf-8 -*-
$LOAD_PATH.push File.expand_path('../lib', __FILE__)
require 'et-knife-ec2/version'

Gem::Specification.new do |s|
  s.name        = 'et-knife-ec2'
  s.version     = Knife::Ec2::VERSION
  s.authors     = ['Eric Herot']
  s.email       = ['eric.herot@evertrue.com']
  s.homepage    = 'http://wiki.opscode.com/display/chef'
  s.summary     = %q{EC2 Support for Chef's Knife Command}
  s.description = s.summary
  s.license     = 'Apache 2.0'

  s.files        = `git ls-files`.split("\n")
  s.test_files   = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables  = `git ls-files -- bin/*`.split('\n').map { |f| File.basename(f) }

  s.add_dependency 'fog',           '~> 1.20.0'
  s.add_dependency 'knife-windows', '>= 0.5.12'
  s.add_dependency 'aws-s3',        '~> 0.6.3'

  s.add_development_dependency 'mixlib-config', '~> 2.0'
  s.add_development_dependency 'chef',          '>= 0.10.10'
  s.add_development_dependency 'rspec',         '~> 2.14'
  s.add_development_dependency 'rake',          '~> 10.1'
  s.add_development_dependency 'sdoc',          '~> 0.3'

  s.require_paths = ['lib']
end