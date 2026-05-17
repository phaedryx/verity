# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe "group_focus (triple suite twin of verity/group_focus_test.rb)" do
  it "verity project isolates :focus narrowing to temp project (subprocess)" do
    lib = File.expand_path("../../lib", __dir__)
    Dir.mktmpdir do |tmp|
      vd = File.join(tmp, "verity")
      FileUtils.mkdir_p(vd)
      File.write(File.join(vd, "only_test.rb"), <<~RUBY)
        group "Focused block", tags: [:focus] do
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

      ok = system(RbConfig.ruby, "-I#{lib}", "-e", script, out: File::NULL, err: File::NULL)
      expect(ok).to be true
    end
  end
end
