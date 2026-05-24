# frozen_string_literal: true

# Triple suite (compare / redundant proof): verity/fingerprint_test.rb · spec/verity/fingerprint_spec.rb

require "minitest/autorun"
require "fileutils"
require_relative "../lib/verity"
require_relative "verity_test_helper"

class FingerprintTest < Minitest::Test
  include VerityTestHelper

  def test_identical_bodies_different_whitespace_share_fingerprint
    reset_verity_process_state!
    Dir.mktmpdir do |dir|
      f = File.join(dir, "one_test.rb")
      Dir.chdir(dir) do
        File.write(f, <<~RUBY)
          test "one" do
            assert   true
          end
        RUBY
        first = Verity::Fingerprint.plan_file(File.expand_path(f)).values.first

        File.write(f, <<~RUBY)
          test "two" do
            assert true
          end
        RUBY
        second = Verity::Fingerprint.plan_file(File.expand_path(f)).values.first

        assert_equal first, second
      end
    end
  end

  def test_description_change_does_not_change_fingerprint
    reset_verity_process_state!
    Dir.mktmpdir do |dir|
      f = File.join(dir, "one_test.rb")
      Dir.chdir(dir) do
        File.write(f, <<~RUBY)
          test "first title" do
            assert true
          end
        RUBY
        a = Verity::Fingerprint.plan_file(File.expand_path(f)).values.first

        File.write(f, <<~RUBY)
          test "second title" do
            assert true
          end
        RUBY
        b = Verity::Fingerprint.plan_file(File.expand_path(f)).values.first

        assert_equal a, b
      end
    end
  end

  def test_different_body_changes_fingerprint
    reset_verity_process_state!
    Dir.mktmpdir do |dir|
      a = File.join(dir, "a_test.rb")
      b = File.join(dir, "b_test.rb")
      File.write(a, <<~RUBY)
        test "x" do
          assert true
        end
      RUBY
      File.write(b, <<~RUBY)
        test "x" do
          assert false
        end
      RUBY

      Dir.chdir(dir) do
        fa = Verity::Fingerprint.plan_file(File.expand_path(a))
        fb = Verity::Fingerprint.plan_file(File.expand_path(b))

        refute_equal fa.values.first, fb.values.first
      end
    end
  end

  def test_duplicate_bodies_get_line_suffix
    reset_verity_process_state!
    Dir.mktmpdir do |dir|
      f = File.join(dir, "d_test.rb")
      File.write(f, <<~RUBY)
        test "a" do
          assert true
        end

        test "b" do
          assert true
        end
      RUBY

      Dir.chdir(dir) do
        plan = Verity::Fingerprint.plan_file(File.expand_path(f))
        fps = plan.values.sort
        assert_equal 2, fps.size
        assert fps.all? { |fp| fp.match?(/:\d+\z/) }, "expected collision suffix on fingerprints: #{fps.inspect}"
      end
    end
  end

  def test_load_discovery_sets_file_line_and_fingerprint
    reset_verity_process_state!
    Dir.mktmpdir do |dir|
      verity_dir = File.join(dir, "verity")
      FileUtils.mkdir_p(verity_dir)
      rb = File.join(verity_dir, "t_test.rb")
      File.write(rb, <<~RUBY)
        test "hi" do
          assert true
        end
      RUBY

      Dir.chdir(dir) do
        Verity.configure { |c| c.test_globs = ["verity/**/*_test.rb"] }
        Verity.load_discovery!

        test = Verity::Registry.all.first
        assert_equal "hi", test.description
        assert_equal File.realpath(File.expand_path(rb)), File.realpath(test.file)
        assert_equal 1, test.line
        assert_match(/\Averity\/t_test\.rb:[a-f0-9]{16}(:\d+)?\z/, test.fingerprint)
      end
    end
  end

  def test_derive_method_suffix_three_part
    reset_verity_process_state!
    assert_equal "deadbeefdeadbeef", Verity::Fingerprint.derive_method_suffix("verity/x_test.rb:deadbeefdeadbeef:12")
    assert_equal "1111111111111111", Verity::Fingerprint.derive_method_suffix("short.rb:1111111111111111")
  end
end
