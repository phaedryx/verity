# frozen_string_literal: true

# Triple suite (compare / redundant proof): verity/run_test.rb · spec/verity/run_spec.rb

require "minitest/autorun"
require "fileutils"
require_relative "../lib/verity"
require_relative "verity_test_helper"

class RunTest < Minitest::Test
  include VerityTestHelper

  # These examples exercise Verity.run in-process; silence the default
  # ColoredDotsReporter so dots/summary lines are not interleaved with Minitest
  # progress (which reads like a failed parallel run right after a success line).
  def reset_verity_process_state!
    super
    Verity.configure { |c| c.reporter = Verity::Reporters::NullReporter.new }
  end

  def test_run_discovers_loads_and_passes
    reset_verity_process_state!
    Dir.mktmpdir do |dir|
      verity_dir = File.join(dir, "verity")
      FileUtils.mkdir_p(verity_dir)
      File.write(File.join(verity_dir, "sample_test.rb"), <<~RUBY)
        test "sample" do
          assert true
        end
      RUBY

      Dir.chdir(dir) do
        Verity.configure do |c|
          c.test_globs = ["verity/**/*_test.rb"]
          c.manifest_path = ":memory:"
          c.worker_count = 1
        end

        outcome = Verity.run(worker_id: 11)

        assert_equal true, outcome
        assert_equal 1, Verity::Registry.all.size
        assert_equal "sample", Verity::Registry.all.first.description
      end
    end
  end

  def test_run_returns_false_when_a_test_fails
    reset_verity_process_state!
    Dir.mktmpdir do |dir|
      verity_dir = File.join(dir, "verity")
      FileUtils.mkdir_p(verity_dir)
      File.write(File.join(verity_dir, "bad_test.rb"), <<~RUBY)
        test "bad" do
          assert false
        end
      RUBY

      Dir.chdir(dir) do
        Verity.configure do |c|
          c.test_globs = ["verity/**/*_test.rb"]
          c.manifest_path = ":memory:"
          c.worker_count = 1
        end

        refute Verity.run(worker_id: 2)
      end
    end
  end

  def test_run_succeeds_with_no_matching_files
    reset_verity_process_state!
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "verity"))

      Dir.chdir(dir) do
        Verity.configure do |c|
          c.test_globs = ["verity/does_not_exist/**/*_test.rb"]
          c.manifest_path = ":memory:"
          c.worker_count = 1
        end

        assert_equal true, Verity.run
        assert_empty Verity::Registry.all
      end
    end
  end

  def test_load_discovery_only_populates_registry
    reset_verity_process_state!
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "verity", "nested"))
      File.write(File.join(dir, "verity", "nested", "one_test.rb"), <<~RUBY)
        test "one" do
          assert true
        end
      RUBY

      Dir.chdir(dir) do
        Verity.configure { |c| c.test_globs = ["verity/**/*_test.rb"] }

        Verity.load_discovery!

        assert_equal 1, Verity::Registry.all.size
      end
    end
  end

  def test_run_rejects_worker_count_below_one
    reset_verity_process_state!
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "verity"))

      Dir.chdir(dir) do
        Verity.configure do |c|
          c.test_globs = ["verity/**/*_test.rb"]
          c.worker_count = 0
        end

        err = assert_raises(ArgumentError) { Verity.run }
        assert_match(/worker_count/, err.message)
      end
    end
  end

  def test_run_rejects_memory_manifest_with_multiple_workers
    omit("fork is not available") unless Process.respond_to?(:fork)

    reset_verity_process_state!
    Dir.mktmpdir do |dir|
      verity_dir = File.join(dir, "verity")
      FileUtils.mkdir_p(verity_dir)
      File.write(File.join(verity_dir, "one_test.rb"), <<~RUBY)
        test "one" do
          assert true
        end
      RUBY

      Dir.chdir(dir) do
        Verity.configure do |c|
          c.manifest_path = ":memory:"
          c.worker_count = 2
        end

        err = assert_raises(ArgumentError) { Verity.run }
        assert_match(/:memory:/, err.message)
      end
    end
  end

  def test_parallel_workers_share_file_manifest_and_pass
    omit("fork is not available") unless Process.respond_to?(:fork)

    reset_verity_process_state!
    Dir.mktmpdir do |dir|
      verity_dir = File.join(dir, "verity")
      FileUtils.mkdir_p(verity_dir)
      tests_src = (0...15).map do |i|
        <<~RUBY
          test "case #{i}" do
          end
        RUBY
      end
      File.write(File.join(verity_dir, "many_test.rb"), tests_src.join("\n"))

      db = File.join(dir, "manifest.db")

      Dir.chdir(dir) do
        Verity.configure do |c|
          c.manifest_path = db
          c.test_globs = ["verity/**/*_test.rb"]
          c.worker_count = 4
        end

        assert_equal true, Verity.run
      end

      manifest = Verity::Manifest.open(db)
      begin
        assert_equal({ "passed" => 15 }, manifest.count_by_status)
      ensure
        manifest.close
      end

      cleanup_sqlite_sidecars(dir)
    end
  end

  def test_parallel_workers_propagate_failure
    omit("fork is not available") unless Process.respond_to?(:fork)

    reset_verity_process_state!
    Dir.mktmpdir do |dir|
      verity_dir = File.join(dir, "verity")
      FileUtils.mkdir_p(verity_dir)
      File.write(File.join(verity_dir, "bad_test.rb"), <<~RUBY)
        test "bad" do
          assert false
        end
      RUBY

      db = File.join(dir, "manifest.db")

      Dir.chdir(dir) do
        Verity.configure do |c|
          c.manifest_path = db
          c.test_globs = ["verity/**/*_test.rb"]
          c.worker_count = 3
        end

        refute Verity.run
      end

      cleanup_sqlite_sidecars(dir)
    end
  end

  private

  def cleanup_sqlite_sidecars(dir)
    Dir.glob(File.join(dir, "manifest.db*")).each do |f|
      File.unlink(f)
    rescue Errno::ENOENT
      # allow tmpdir cleanup on forks + WAL
    end
  end
end
