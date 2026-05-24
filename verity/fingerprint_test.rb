# frozen_string_literal: true

require "fileutils"
require "tmpdir"

# Dogfood mirror of test/fingerprint_test.rb

test "identical bodies different whitespace share fingerprint" do
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

      assert_equal actual: first, expected: second
    end
  end
end

test "description change does not change fingerprint" do
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

      assert_equal actual: a, expected: b
    end
  end
end

test "different body changes fingerprint" do
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

      refute_equal actual: fa.values.first, expected: fb.values.first
    end
  end
end

test "derive_method_suffix parses file line fingerprints" do
  assert_equal(
    actual: Verity::Fingerprint.derive_method_suffix("verity/x_test.rb:deadbeefdeadbeef:12"),
    expected: "deadbeefdeadbeef"
  )
  assert_equal(
    actual: Verity::Fingerprint.derive_method_suffix("short.rb:1111111111111111"),
    expected: "1111111111111111"
  )
end

test "duplicate bodies get line suffix on fingerprints" do
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
      assert_equal actual: fps.size, expected: 2
      assert fps.all? { |fp| fp.match?(/:\d+\z/) }
    end
  end
end

test "load_discovery sets description file line fingerprint subprocess" do
  lib = File.join(File.expand_path("..", __dir__), "lib")
  Dir.mktmpdir do |dir|
    verity_dir = File.join(dir, "verity")
    FileUtils.mkdir_p(verity_dir)
    rb_path = File.join(verity_dir, "t_test.rb")
    File.write(rb_path, <<~RUBY)
      test "hi" do
        assert true
      end
    RUBY

    script = <<~RUBY
      require "verity"
      rb = #{rb_path.inspect}
      Dir.chdir(#{dir.inspect}) do
        Verity.reset_configuration!
        Verity.configure { |c| c.test_globs = ["verity/**/*_test.rb"] }
        Verity.load_discovery!
        t = Verity::Registry.all.first
        fp_ok = t.fingerprint.match?(/\\Averity\\/t_test\\.rb:[a-f0-9]{16}(:\\d+)?\\z/)
        path_ok = File.realpath(File.expand_path(rb)) == File.realpath(t.file)
        ok = t.description == "hi" && path_ok && t.line == 1 && fp_ok
        exit(ok ? 0 : 1)
      end
    RUBY

    assert system(RbConfig.ruby, "-I#{lib}", "-e", script, out: File::NULL, err: File::NULL)
  end
end
