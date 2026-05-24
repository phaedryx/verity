# frozen_string_literal: true

require_relative "lib/verity/version"

Gem::Specification.new do |spec|
  spec.name    = "verity"
  spec.version = Verity::VERSION
  spec.authors = ["Tad Thorley"]

  spec.summary     = "Metadata-first Ruby test framework"
  spec.description = <<~DESC
    Verity is a Ruby test framework built around a core principle: tests are
    executable data structures, not a nested DSL. Each test carries structured
    metadata (tags, timeout, resource declarations) used for CI filtering,
    parallel grouping, and scheduling. Execution uses process-level forking
    with a SQLite manifest as the work queue and result store.
  DESC

  spec.homepage = "https://github.com/phaedryx/verity"
  spec.license  = "MIT"

  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata = {
    "homepage_uri"    => spec.homepage,
    "source_code_uri" => spec.homepage,
    "bug_tracker_uri" => "#{spec.homepage}/issues"
  }

  spec.files = Dir["lib/**/*.rb", "bin/*", "LICENSE", "README.md"]
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{\Abin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "sqlite3", "~> 2.0"
  spec.add_dependency "prism",  "~> 1.0"

  spec.add_development_dependency "minitest"
  spec.add_development_dependency "rubocop", "~> 1.75"
  spec.add_development_dependency "rspec"
end
