# frozen_string_literal: true

# Exercises the bin/verity CLI exit-code contract for invalid options.
require "minitest/autorun"
require "open3"
require "tmpdir"

class CliTest < Minitest::Test
  BIN = File.expand_path("../bin/verity", __dir__)

  # Run bin/verity in an empty directory so a successful parse cannot discover
  # and execute real test files as a side effect.
  def run_cli(*args)
    Dir.mktmpdir { |dir| return Open3.capture3(RbConfig.ruby, BIN, *args, chdir: dir) }
  end

  def test_unknown_reporter_exits_2_with_clean_message
    _out, err, status = run_cli("-r", "bogus")

    assert_equal 2, status.exitstatus, "unknown --reporter should exit 2 (stderr: #{err})"
    assert_match(/unknown reporter/, err)
    refute_match(/\(ArgumentError\)|:in [`']/, err, "expected a clean message, not a Ruby backtrace")
  end
end
