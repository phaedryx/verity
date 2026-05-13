# frozen_string_literal: true

require "fileutils"
require "tmpdir"

# Dogfood mirror of test/build_reporter_test.rb

test "build_reporter documentation" do
  assert Verity.build_reporter("documentation").is_a?(Verity::Reporters::DocumentationReporter)
  assert Verity.build_reporter("DOC").is_a?(Verity::Reporters::DocumentationReporter)
end

test "build_reporter colored and dots" do
  assert Verity.build_reporter("colored").is_a?(Verity::Reporters::ColoredDotsReporter)
  assert Verity.build_reporter("COLORED_DOTS").is_a?(Verity::Reporters::ColoredDotsReporter)
  assert Verity.build_reporter("dots").is_a?(Verity::Reporters::DotsReporter)
end

test "build_reporter null aliases" do
  assert Verity.build_reporter("null").is_a?(Verity::Reporters::NullReporter)
  assert Verity.build_reporter("silent").is_a?(Verity::Reporters::NullReporter)
end

test "build_reporter blank raises" do
  assert_raises(ArgumentError) { Verity.build_reporter(nil) }
  assert_raises(ArgumentError) { Verity.build_reporter("   ") }
end

test "build_reporter unknown name raises" do
  err = assert_raises(ArgumentError) { Verity.build_reporter("nope") }
  assert_match pattern: /unknown reporter/, actual: err.message
end

test "build_reporter custom path and class" do
  Dir.mktmpdir do |dir|
    path = File.join(dir, "mine.rb")
    File.write(path, <<~RUBY)
      class CliReporterForDogfood
        include Verity::Reporter
      end
    RUBY

    rep = Verity.build_reporter("#{path}:CliReporterForDogfood")
    assert rep.is_a?(CliReporterForDogfood)
  end
end
