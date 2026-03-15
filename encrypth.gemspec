require_relative "lib/encrypth/version"

Gem::Specification.new do |spec|
  spec.name = "encrypth"
  spec.version = Encrypth::VERSION
  spec.authors = ["Irina Grigorian"]
  spec.email = ["irigorian@sfedu.ru"]
  
  spec.summary = "a simple wrapper for encryption."
  spec.description = "a gem with aes-256-gcm standard to make encrypting easy and safe."
  spec.homepage = "https://github.com/smokinblackdog/encrypth.git"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"
  
  spec.files = Dir.glob("lib/**/*.rb") + ["Rakefile", "README.md"]
  spec.require_paths = ["lib"]
  
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
end