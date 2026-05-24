# frozen_string_literal: true

# Triple suite (compare / redundant proof): verity/configuration_test.rb · spec/verity/configuration_spec.rb

require "minitest/autorun"
require "fileutils"
require_relative "../lib/verity"
require_relative "verity_test_helper"

class ConfigurationTest < Minitest::Test
  include VerityTestHelper

  def test_defaults_use_file_manifest_cpus_workers_and_test_globs
    # Arrange
    reset_verity_configuration_only!

    # Act
    config = Verity.configuration

    # Assert
    assert_equal "verity/manifest.db", config.manifest_path
    refute_predicate config, :memory_manifest?
    assert_equal ["verity/**/*_test.rb"], config.test_globs
    assert_equal :cpus, config.worker_count
    assert_equal :random, config.test_order
    assert_nil config.shuffle_seed
    assert_equal [], config.location_filters
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

  def test_ordered_runnable_random_explicit_seed_is_reproducible_and_silent
    Verity.reset_configuration!
    Verity::Registry.clear
    Verity.configure do |c|
      c.test_order = :random
      c.shuffle_seed = 13_579
    end
    %w[a b c].each do |name|
      Verity::Registry.register(
        Verity::Test.new(
          fingerprint: "#{name}.rb:#{name * 16}",
          description: name,
          tags: [],
          timeout: nil,
          requires: [],
          resources: {},
          file: "#{name}.rb",
          line: 1,
          fn: -> {},
          group_path: [].freeze,
          inherited_group_tags: [].freeze,
          group_scopes: [].freeze
        )
      )
    end
    first = nil
    err = capture_io { first = Verity.send(:ordered_runnable_tests).map(&:fingerprint) }.last
    assert_empty err

    Verity::Registry.clear
    %w[a b c].each do |name|
      Verity::Registry.register(
        Verity::Test.new(
          fingerprint: "#{name}.rb:#{name * 16}",
          description: name,
          tags: [],
          timeout: nil,
          requires: [],
          resources: {},
          file: "#{name}.rb",
          line: 1,
          fn: -> {},
          group_path: [].freeze,
          inherited_group_tags: [].freeze,
          group_scopes: [].freeze
        )
      )
    end
    Verity.configure do |c|
      c.test_order = :random
      c.shuffle_seed = 13_579
    end
    second = nil
    err2 = capture_io { second = Verity.send(:ordered_runnable_tests).map(&:fingerprint) }.last
    assert_empty err2
    assert_equal first, second
  end

  def test_ordered_runnable_random_auto_seed_prints_integer_line_to_stderr
    Verity.reset_configuration!
    Verity::Registry.clear
    Verity.configure do |c|
      c.test_order = :random
      c.shuffle_seed = nil
    end
    %w[a b c].each do |name|
      Verity::Registry.register(
        Verity::Test.new(
          fingerprint: "#{name}.rb:#{name * 16}",
          description: name,
          tags: [],
          timeout: nil,
          requires: [],
          resources: {},
          file: "#{name}.rb",
          line: 1,
          fn: -> {},
          group_path: [].freeze,
          inherited_group_tags: [].freeze,
          group_scopes: [].freeze
        )
      )
    end
    err = capture_io { Verity.send(:ordered_runnable_tests) }.last
    assert_match(/\A\d+\n\z/, err)
    assert_kind_of Integer, Verity.configuration.shuffle_seed
  end

  def test_shuffle_seed_implies_random_order_even_when_test_order_fingerprint
    Verity.reset_configuration!
    Verity::Registry.clear
    Verity.configure do |c|
      c.test_order = :fingerprint
      c.shuffle_seed = 42
    end
    %w[z a m].each do |name|
      Verity::Registry.register(
        Verity::Test.new(
          fingerprint: "#{name}.rb:#{name * 16}",
          description: name,
          tags: [],
          timeout: nil,
          requires: [],
          resources: {},
          file: "#{name}.rb",
          line: 1,
          fn: -> {},
          group_path: [].freeze,
          inherited_group_tags: [].freeze,
          group_scopes: [].freeze
        )
      )
    end
    first = Verity.send(:ordered_runnable_tests).map(&:fingerprint)
    refute_equal first.sort, first

    Verity::Registry.clear
    %w[z a m].each do |name|
      Verity::Registry.register(
        Verity::Test.new(
          fingerprint: "#{name}.rb:#{name * 16}",
          description: name,
          tags: [],
          timeout: nil,
          requires: [],
          resources: {},
          file: "#{name}.rb",
          line: 1,
          fn: -> {},
          group_path: [].freeze,
          inherited_group_tags: [].freeze,
          group_scopes: [].freeze
        )
      )
    end
    Verity.configure do |c|
      c.test_order = :fingerprint
      c.shuffle_seed = 42
    end
    second = Verity.send(:ordered_runnable_tests).map(&:fingerprint)
    assert_equal first, second
  end

  def test_ordered_runnable_fingerprint_sorts
    Verity.reset_configuration!
    Verity::Registry.clear
    Verity.configure { |c| c.test_order = :fingerprint }
    %w[z a m].each do |name|
      Verity::Registry.register(
        Verity::Test.new(
          fingerprint: "#{name}.rb:#{name * 16}",
          description: name,
          tags: [],
          timeout: nil,
          requires: [],
          resources: {},
          file: "#{name}.rb",
          line: 1,
          fn: -> {},
          group_path: [].freeze,
          inherited_group_tags: [].freeze,
          group_scopes: [].freeze
        )
      )
    end
    fingerprints = Verity.send(:ordered_runnable_tests).map(&:fingerprint)
    assert_equal fingerprints.sort, fingerprints
  end
end
