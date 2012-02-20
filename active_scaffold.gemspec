# -*- encoding: utf-8 -*-
$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'active_scaffold/version'

Gem::Specification.new do |s|
  s.name = %q{active_scaffold-sequel}
  s.version = ActiveScaffold::Version::STRING
  s.platform = Gem::Platform::RUBY
  s.email = %q{nospam@example.com}
  s.authors = ["Many, see README"]
  s.homepage = %q{http://as-seq.rubyforge.org/}
  s.summary = %q{ActiveScaffold version supporting Sequel with Rails 3.1.}
  s.description = %q{The original ActiveScaffold supports Rails (http://rubyonrails.org/) with it's native ORM ActiveRecord. This version replaces support for ActiveRecord with support for Sequel (http://sequel.rubyforge.org/).}
  s.require_paths = ["lib"]
  s.files = Dir["{app,config,frontends,lib,public,shoulda_macros,vendor}/**/*"] + %w[MIT-LICENSE CHANGELOG README]
  s.extra_rdoc_files = [
    "README"
  ]
  s.licenses = ["MIT"]
  s.test_files = Dir["test/**/*"]

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=

  s.add_development_dependency(%q<shoulda>, [">= 0"])
  s.add_development_dependency(%q<bundler>, ["~> 1.0.0"])
  s.add_development_dependency(%q<rcov>, [">= 0"])
  s.add_runtime_dependency(%q<rails>, [">= 3.1.3"])
  s.add_runtime_dependency(%q<sequel>, [">= 0"])
end
