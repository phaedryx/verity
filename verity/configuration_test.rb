# frozen_string_literal: true

require "fileutils"
require "tmpdir"

# Dogfood mirror of test/configuration_test.rb

test "configuration defaults" do
  Verity.reset_configuration!
  tmpl = Verity::Configuration.new
  cfg = Verity.configuration
  assert_equal actual: cfg.manifest_path, expected: tmpl.manifest_path
  refute cfg.memory_manifest?
  assert_equal actual: cfg.test_globs, expected: tmpl.test_globs
  assert_equal actual: tmpl.test_order, expected: :random
  assert_nil tmpl.shuffle_seed
  assert_equal actual: cfg.location_filters, expected: tmpl.location_filters
  assert tmpl.reporter.is_a?(Verity::Reporters::ColoredDotsReporter)
ensure
  Verity.reset_configuration!
end

test "resolved_worker_count matches Etc.nprocessors for :cpus" do
  Verity.reset_configuration!
  Verity.configure { |c| c.worker_count = :cpus }
  expected = [Etc.nprocessors, 1].max
  assert_equal actual: Verity.configuration.resolved_worker_count, expected: expected
ensure
  Verity.reset_configuration!
end

test "resolved_worker_count matches Etc.nprocessors for cpus string" do
  Verity.reset_configuration!
  Verity.configure { |c| c.worker_count = "  CPUs " }
  expected = [Etc.nprocessors, 1].max
  assert_equal actual: Verity.configuration.resolved_worker_count, expected: expected
ensure
  Verity.reset_configuration!
end

test "resolved_worker_count matches Etc.nprocessors for :cpu singular" do
  Verity.reset_configuration!
  Verity.configure { |c| c.worker_count = :cpu }
  expected = [Etc.nprocessors, 1].max
  assert_equal actual: Verity.configuration.resolved_worker_count, expected: expected
ensure
  Verity.reset_configuration!
end

test "resolved_worker_count matches Etc.nprocessors for cpu singular string" do
  Verity.reset_configuration!
  Verity.configure { |c| c.worker_count = "cpu" }
  expected = [Etc.nprocessors, 1].max
  assert_equal actual: Verity.configuration.resolved_worker_count, expected: expected
ensure
  Verity.reset_configuration!
end

test "resolved_worker_count rejects invalid worker_count" do
  Verity.reset_configuration!
  Verity.configure { |c| c.worker_count = :not_a_number }
  err = assert_raises ArgumentError do
    Verity.configuration.resolved_worker_count
  end
  assert_match pattern: /worker_count/, actual: err.message
ensure
  Verity.reset_configuration!
end

test "configure overrides manifest and globs" do
  Verity.reset_configuration!
  Verity.configure do |c|
    c.manifest_path = "tmp/verity.sqlite"
    c.test_globs = ["spec/**/*_spec.rb", "custom/**/test_*.rb"]
    c.worker_count = 4
  end
  config = Verity.configuration
  assert_equal actual: config.manifest_path, expected: "tmp/verity.sqlite"
  refute config.memory_manifest?
  assert_equal actual: config.test_globs, expected: ["spec/**/*_spec.rb", "custom/**/test_*.rb"]
  assert_equal actual: config.worker_count, expected: 4
ensure
  Verity.reset_configuration!
end

test "test_files respects default glob under verity" do
  Verity.reset_configuration!
  Dir.mktmpdir do |tmpdir|
    nested = File.join(tmpdir, "verity", "nested")
    FileUtils.mkdir_p(nested)
    File.write(File.join(tmpdir, "verity", "one_test.rb"), "")
    File.write(File.join(tmpdir, "verity", "skip.rb"), "")
    File.write(File.join(nested, "two_test.rb"), "")

    Dir.chdir(tmpdir) do
      files = Verity.configuration.test_files
      assert_equal actual: files, expected: %w[verity/nested/two_test.rb verity/one_test.rb]
    end
  end
ensure
  Verity.reset_configuration!
end

test "test_files merges globs without duplicates" do
  Verity.reset_configuration!
  Dir.mktmpdir do |tmpdir|
    verity_dir = File.join(tmpdir, "verity")
    test_dir = File.join(tmpdir, "test")
    FileUtils.mkdir_p([verity_dir, test_dir])
    File.write(File.join(verity_dir, "a_test.rb"), "")
    File.write(File.join(test_dir, "b_test.rb"), "")

    Dir.chdir(tmpdir) do
      Verity.configure do |c|
        c.test_globs = ["verity/**/*_test.rb", "test/**/*_test.rb", "verity/**/*.rb"]
      end
      files = Verity.configuration.test_files
      assert_equal actual: files, expected: %w[test/b_test.rb verity/a_test.rb]
    end
  end
ensure
  Verity.reset_configuration!
end
