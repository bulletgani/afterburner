#lib = File.expand_path('../lib/', __FILE__)
# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "afterburner/version"

Gem::Specification.new do |s|
  s.name        = "afterburner"
  s.version     = Afterburner::VERSION
  s.authors     = ["Ganesha Bhaskara"]
  s.email       = ["ganesha@bhaskara.org"]
  s.homepage    = "https://github.com/bulletgani/afterburner"
  s.summary     = %q{DB Sharding for ActiveRecord}
  s.description = %q{This gem allows you to use sharded databases with ActiveRecord. This also provides a interface for replication and for running migrations with multiples shards.}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]


  s.add_dependency 'awesome_print'
  s.add_dependency 'mysql2', '>= 0.3.7'
  s.add_dependency 'hiredis', '~> 0.4.1'
  s.add_dependency 'redis', '~> 2.2.2'
  s.add_dependency 'uuid'
  s.add_dependency 'resque'
  s.add_runtime_dependency(%q<activerecord>, [">= 3.0"])
  s.add_runtime_dependency(%q<railties>, [">= 3.0"])
end
