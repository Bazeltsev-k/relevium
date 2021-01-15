# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "application_utilities/version"

Gem::Specification.new do |spec|
  spec.name          = "application_utilities"
  spec.version       = ApplicationUtilities::VERSION
  spec.authors       = ['Bazeltsev Kirill']
  spec.email         = ['kirill.bazeltsev@flender.ie']

  spec.summary       = 'A Ruby gem, that helps keep models and controllers thin'
  spec.description   = ''
  spec.homepage      = ''
  spec.license       = 'MIT'

  spec.add_dependency 'activemodel', '=> 4.2.6'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "=> 1.15"
  spec.add_development_dependency "rake", "=> 10.0"
  spec.add_development_dependency "rspec", "=> 3.5.0"
  spec.add_development_dependency "byebug", '=> 11.0.1'
end
