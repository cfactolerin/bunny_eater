
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "bunny_eater/version"

Gem::Specification.new do |spec|
  spec.name          = "bunny_eater"
  spec.version       = BunnyEater::VERSION
  spec.authors       = ["Cris Factolerin"]
  spec.email         = ["cris@perxtech.com"]

  spec.summary       = "This gem will pull data from a RabbitMQ server and store the messages in S3"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = ["bunny_eater"]
  spec.require_paths = ["lib"]

  spec.add_dependency "bunny", "~> 2.9.0" # Needed to access RabbitMQ
  spec.add_dependency "aws-sdk-s3"

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "dotenv"
  spec.add_development_dependency "bunny-mock"

end
