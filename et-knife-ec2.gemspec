# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "et-knife-ec2/version"

Gem::Specification.new do |s|
  s.name        = "et-knife-ec2"
  s.version     = Knife::Ec2::VERSION
  s.has_rdoc = true
  s.authors     = ["Eric Herot"]
  s.email       = ["eric.herot@evertrue.com"]
  s.homepage = "http://wiki.opscode.com/display/chef"
  s.summary = "EC2 Support for Chef's Knife Command"
  s.description = s.summary
  s.extra_rdoc_files = ["README.rdoc", "LICENSE" ]

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.add_dependency "fog", "~> 1.6"
  s.add_dependency "chef", ">= 0.10.10"
  s.add_dependency "knife-windows", ">= 0.5.12"
  %w(rspec-core rspec-expectations rspec-mocks  rspec_junit_formatter).each { |gem| s.add_development_dependency gem }
  s.add_dependency "aws-s3"

  s.require_paths = ["lib"]
end
