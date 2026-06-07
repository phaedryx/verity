# frozen_string_literal: true

# Example Verity + Rails setup. Prefer: bin/rails generate verity:install
#
#   bin/verity
#   bin/rake verity -- -r documentation
#
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "verity/rails"

Verity.configure do |c|
  c.test_globs = ["test/verity/**/*_test.rb"]
  c.manifest_path = "tmp/verity_manifest.db"
  c.worker_count = ENV.fetch("VERITY_WORKERS", "cpus")
end

Verity::Rails.configure do |c|
  c.transactional_tests = true
  c.reconnect_after_fork = true
  c.per_worker_database = ENV["VERITY_PER_WORKER_DB"] == "1"
  c.fixture_sets = [:users] # or :all
  c.delegate_http_methods = false
end

Verity.register_resource :tables,
  conflicts_with: ->(mine, theirs) { (mine & theirs).any? }

Verity::Rails.install!
