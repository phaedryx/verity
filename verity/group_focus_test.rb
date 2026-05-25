# frozen_string_literal: true

# Triple suite: spec/verity/group_focus_spec.rb (Minitest group-focus coverage lives in test/group_test.rb)
# Runs in subprocess so `:focus` in this scenario never narrows the rest of dogfood CI.

require "tmpdir"
require "fileutils"

test "verity project group focus narrows runnable list" do
  lib = File.join(File.expand_path("..", __dir__), "lib")
  Dir.mktmpdir do |tmp|
    verity_dir = File.join(tmp, "verity")
    FileUtils.mkdir_p(verity_dir)
    File.write(File.join(verity_dir, "only_test.rb"), <<~RUBY)
      group "Focused block", focus: true do
        test "inside" do
          assert true
        end
      end
      test "outside" do
        assert true
      end
    RUBY

    script = <<~RUBY
      require "verity"
      Dir.chdir(#{tmp.inspect}) do
        Verity.reset_configuration!
        Verity.configure do |c|
          c.test_globs = ["verity/**/*_test.rb"]
          c.manifest_path = ":memory:"
          c.reporter = Verity::Reporters::NullReporter.new
          c.worker_count = 1
        end
        Verity.load_discovery!
        names = Verity.runnable_tests.map(&:description).sort
        without_skip = Verity::Registry.all.reject { Verity.skipped?(_1) }
        unless names == ["inside"] && Verity.focus_filter_active?(without_skip)
          warn names.inspect
          exit 1
        end
      end
    RUBY

    assert system(RbConfig.ruby, "-I#{lib}", "-e", script, out: File::NULL, err: File::NULL)
  end
end
