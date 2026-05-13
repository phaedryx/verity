# frozen_string_literal: true

require "fileutils"
require "tmpdir"

# Dogfood mirror of test/focus_tag_test.rb — no :focus examples registered at load time (would narrow suite).

test "focus_tag? is true when focus in tags" do
  t = Verity::Test.new(
    fingerprint: "f.rb:#{"f" * 16}",
    description: "f",
    tags: [:focus],
    timeout: nil,
    requires: [],
    resources: {},
    file: "f.rb",
    line: 1,
    fn: -> {},
    group_path: [],
    inherited_group_tags: []
  )
  assert Verity.focus_tag?(t)
end

test "focus_filter_active? false for empty candidates" do
  refute Verity.focus_filter_active?([])
end

test "skip wins over focus on same test" do
  t = Verity::Test.new(
    fingerprint: "sf.rb:#{"a" * 16}",
    description: "both",
    tags: %i[skip focus],
    timeout: nil,
    requires: [],
    resources: {},
    file: "sf.rb",
    line: 1,
    fn: -> {},
    group_path: [],
    inherited_group_tags: []
  )
  assert Verity.skipped?(t)
end

test "verity run honors focus in isolated project" do
  lib = File.join(File.expand_path("..", __dir__), "lib")
  Dir.mktmpdir do |dir|
    verity_dir = File.join(dir, "verity")
    FileUtils.mkdir_p(verity_dir)
    File.write(File.join(verity_dir, "t_test.rb"), <<~RUBY)
      test "ignored" do
        assert false
      end

      test "only", tags: [:focus] do
        assert true
      end
    RUBY

    script = <<~RUBY
      require "verity"
      Dir.chdir(#{dir.inspect}) do
        Verity.reset_configuration!
        Verity.configure do |c|
          c.test_globs = ["verity/**/*_test.rb"]
          c.manifest_path = ":memory:"
        end
        ok = Verity.run
        reg = Verity::Registry.all.size
        runn = Verity.runnable_tests.size
        exit(ok && reg == 2 && runn == 1 ? 0 : 1)
      end
    RUBY

    assert system(RbConfig.ruby, "-I#{lib}", "-e", script, out: File::NULL, err: File::NULL)
  end
end
