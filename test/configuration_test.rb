# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require_relative "../lib/verity"
require_relative "verity_test_helper"

class ConfigurationTest < Minitest::Test
  include VerityTestHelper

  def test_defaults_use_memory_manifest_and_test_globs
    # Arrange
    reset_verity_configuration_only!

    # Act
    config = Verity.configuration

    # Assert
    assert_equal ":memory:", config.manifest_path
    assert_predicate config, :memory_manifest?
    assert_equal ["verity/**/*_test.rb"], config.test_globs
    assert_equal 1, config.worker_count
    assert_instance_of Verity::Reporters::ColoredDotsReporter, config.reporter
  end

  def test_configure_sets_values
    # Arrange
    reset_verity_configuration_only!

    # Act
    Verity.configure do |c|
      c.manifest_path = "tmp/verity.sqlite"
      c.test_globs = ["spec/**/*_spec.rb", "custom/**/test_*.rb"]
      c.worker_count = 4
    end

    # Assert
    config = Verity.configuration
    assert_equal "tmp/verity.sqlite", config.manifest_path
    refute_predicate config, :memory_manifest?
    assert_equal ["spec/**/*_spec.rb", "custom/**/test_*.rb"], config.test_globs
    assert_equal 4, config.worker_count
  end

  def test_resolved_worker_count_uses_cpus_token
    reset_verity_configuration_only!
    Verity.configure { |c| c.worker_count = :cpus }
    expected = [Etc.nprocessors, 1].max
    assert_equal expected, Verity.configuration.resolved_worker_count
  end

  def test_resolved_worker_count_accepts_cpus_string
    reset_verity_configuration_only!
    Verity.configure { |c| c.worker_count = "cpus" }
    expected = [Etc.nprocessors, 1].max
    assert_equal expected, Verity.configuration.resolved_worker_count
  end

  def test_resolved_worker_count_accepts_cpu_singular_symbol
    reset_verity_configuration_only!
    Verity.configure { |c| c.worker_count = :cpu }
    expected = [Etc.nprocessors, 1].max
    assert_equal expected, Verity.configuration.resolved_worker_count
  end

  def test_resolved_worker_count_accepts_cpu_singular_string
    reset_verity_configuration_only!
    Verity.configure { |c| c.worker_count = "cpu" }
    expected = [Etc.nprocessors, 1].max
    assert_equal expected, Verity.configuration.resolved_worker_count
  end

  def test_resolved_worker_count_rejects_invalid_value
    reset_verity_configuration_only!
    Verity.configure { |c| c.worker_count = :invalid }
    err = assert_raises(ArgumentError) { Verity.configuration.resolved_worker_count }
    assert_match(/worker_count/, err.message)
  end

  def test_test_files_respects_default_glob_under_verity
    reset_verity_configuration_only!
    Dir.mktmpdir do |tmpdir|
      nested = File.join(tmpdir, "verity", "nested")
      FileUtils.mkdir_p(nested)
      File.write(File.join(tmpdir, "verity", "one_test.rb"), "")
      File.write(File.join(tmpdir, "verity", "skip.rb"), "")
      File.write(File.join(nested, "two_test.rb"), "")

      Dir.chdir(tmpdir) do
        # Act — default test_globs
        files = Verity.configuration.test_files

        # Assert
        assert_equal %w[verity/nested/two_test.rb verity/one_test.rb], files
      end
    end
  end

  def test_test_files_merges_multiple_globs_without_duplicates
    reset_verity_configuration_only!
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

        assert_equal %w[test/b_test.rb verity/a_test.rb], files
      end
    end
  end
end
