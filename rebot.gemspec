# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rebot/version'

Gem::Specification.new do |spec|
  spec.name          = "rebot"
  spec.version       = Rebot::VERSION
  spec.authors       = ["Artyom Keydunov"]
  spec.email         = ["artyom.keydunov@gmail.com"]

  spec.summary       = %q{Framework for building bot applications}
  spec.description   = %q{Framework for building bot applications}
  spec.homepage      = "https://github.com/keydunov/rebot"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = "~>2.0"

  spec.add_runtime_dependency "eventmachine"
  spec.add_runtime_dependency "faye-websocket"
  spec.add_runtime_dependency "thor"
  spec.add_runtime_dependency "faraday"
  spec.add_runtime_dependency "slack-web-api"
  spec.add_runtime_dependency "redis"

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
end
