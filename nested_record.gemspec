
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "nested_record/version"

Gem::Specification.new do |spec|
  spec.name          = "nested_record"
  spec.version       = NestedRecord::VERSION
  spec.authors       = ["Vladimir Kochnev"]
  spec.email         = ["hashtable@yandex.ru"]

  spec.summary       = %q{ActiveModel mapper for JSON fields}
  spec.homepage      = "https://github.com/marshall-lee/nested_record"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", ">= 2"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "appraisal"

  spec.add_dependency "activemodel", ">= 4.2", "< 6.2"
end
