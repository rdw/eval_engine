require_relative "lib/eval_engine/version"

Gem::Specification.new do |spec|
  spec.name        = "eval_engine"
  spec.version     = EvalEngine::VERSION
  spec.authors     = [ "Ryan Duane Williams" ]
  spec.email       = [ "breath@alum.mit.edu" ]
  spec.homepage    = "TODO"
  spec.summary     = "TODO: Summary of EvalEngine."
  spec.description = "TODO: Description of EvalEngine."
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,exe,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.bindir = "exe"
  spec.executables = ["eval-cli"]

  spec.add_dependency "rails", ">= 8.1.3"
  spec.add_dependency "thor", ">= 1.0"
end
