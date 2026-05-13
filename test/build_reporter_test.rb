# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require_relative "../lib/verity"

class BuildReporterTest < Minitest::Test
  def test_built_ins
    assert_instance_of Verity::Reporters::DocumentationReporter, Verity.build_reporter("documentation")
    assert_instance_of Verity::Reporters::DocumentationReporter, Verity.build_reporter("DOC")
    assert_instance_of Verity::Reporters::ColoredDotsReporter, Verity.build_reporter("colored")
    assert_instance_of Verity::Reporters::ColoredDotsReporter, Verity.build_reporter("COLORED_DOTS")
    assert_instance_of Verity::Reporters::DotsReporter, Verity.build_reporter("dots")
    assert_instance_of Verity::Reporters::NullReporter, Verity.build_reporter("null")
    assert_instance_of Verity::Reporters::NullReporter, Verity.build_reporter("silent")
  end

  def test_blank_raises
    assert_raises(ArgumentError) { Verity.build_reporter(nil) }
    assert_raises(ArgumentError) { Verity.build_reporter("   ") }
  end

  def test_unknown_without_colon_raises
    err = assert_raises(ArgumentError) { Verity.build_reporter("nope") }
    assert_match(/unknown reporter/, err.message)
  end

  def test_custom_file_and_class
    Dir.mktmpdir do |dir|
      path = File.join(dir, "mine.rb")
      File.write(path, <<~RUBY)
        class CliReporterForTest
          include Verity::Reporter
        end
      RUBY

      rel = File.join(dir, "mine.rb")
      rep = Verity.build_reporter("#{rel}:CliReporterForTest")
      assert_instance_of CliReporterForTest, rep
    end
  end
end
