# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "pathname"
require "verity"
require "verity/cli"
require "verity/rails"
require "verity_test_helper"

class CliModuleTest < Minitest::Test
  include VerityTestHelper

  def setup
    reset_verity_process_state!
  end

  def test_run_returns_0_when_all_tests_pass
    with_temp_test_file(body: "test \"passes\" do\n  assert true\nend") do
      assert_equal 0, Verity::CLI.run([])
    end
  end

  def test_run_returns_1_on_assertion_failure
    with_temp_test_file(body: "test \"fails\" do\n  assert false\nend") do
      assert_equal 1, Verity::CLI.run([])
    end
  end

  def test_parse_unknown_order_raises_parse_error
    err = assert_raises(Verity::CLI::ParseError) { Verity::CLI.parse!(%w[--order bogus]) }
    assert_match(/fingerprint or random/, err.message)
  end

  def test_positional_paths_configure_globs
    Dir.mktmpdir do |dir|
      file = File.join(dir, "one_test.rb")
      File.write(file, "test \"x\" { assert true }\n")
      argv = [file]
      Verity::CLI.parse!(argv)
      assert_equal [file], argv
      assert_includes Verity.configuration.test_files, file
    end
  end

  private

  def with_temp_test_file(body:)
    Dir.mktmpdir do |dir|
      file = File.join(dir, "pass_test.rb")
      File.write(file, "# frozen_string_literal: true\n#{body}\n")
      Verity.configure do |c|
        c.test_globs = [file]
        c.manifest_path = ":memory:"
        c.test_order = :fingerprint
        c.worker_count = 1
        c.reporter = Verity::Reporters::NullReporter.new
      end
      yield
    end
  end
end

class RailsRunnerTest < Minitest::Test
  include VerityTestHelper

  def setup
    reset_verity_process_state!
    @root = Pathname(Dir.mktmpdir)
    stub_rails_root!(@root)
  end

  def teardown
    Object.send(:remove_const, :Rails) if defined?(Rails) && Rails.is_a?(Module) && Rails.name == "Rails"
  end

  def test_helper_path_missing_returns_nil
    assert_nil Verity::Rails::Runner.helper_path
  end

  def test_load_helper_raises_when_missing
    assert_raises(Verity::Rails::Runner::HelperNotFound) do
      Verity::Rails::Runner.load_helper!
    end
  end

  def test_load_helper_loads_file_once
    helper = @root.join("test/verity_helper.rb")
    helper.dirname.mkpath
    helper.write(<<~RUBY)
      $verity_helper_hits ||= 0
      $verity_helper_hits += 1
      Verity.configure { |c| c.test_order = :fingerprint }
    RUBY

    Verity::Rails::Runner.load_helper!
    Verity::Rails::Runner.load_helper!
    assert_equal 1, $verity_helper_hits
  ensure
    $verity_helper_hits = nil
  end

  def test_rake_argv_returns_tokens_after_separator
    argv = %w[verity:run -- -w 4 -t slow]
    assert_equal %w[-w 4 -t slow], Verity::Rails::Runner.rake_argv(argv)
  end

  def test_rake_argv_empty_without_separator
    assert_equal [], Verity::Rails::Runner.rake_argv(%w[verity:run])
  end

  private

  def stub_rails_root!(root)
    Object.send(:remove_const, :Rails) if defined?(Rails)
    rails = Module.new
    rails.define_singleton_method(:root) { root }
    Object.const_set(:Rails, rails)
  end
end
