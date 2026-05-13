# frozen_string_literal: true

require "fileutils"
require "sqlite3"
require "tmpdir"

# Dogfood mirror of test/run_test.rb — Verity.run / load_discovery! only in subprocess (clearing Registry).

test "run discovers passes in isolated project" do
  lib = File.join(File.expand_path("..", __dir__), "lib")
  Dir.mktmpdir do |dir|
    verity_dir = File.join(dir, "verity")
    FileUtils.mkdir_p(verity_dir)
    File.write(File.join(verity_dir, "sample_test.rb"), <<~RUBY)
      test "sample" do
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
        exit(Verity.run(worker_id: 11) ? 0 : 1)
      end
    RUBY

    assert system(RbConfig.ruby, "-I#{lib}", "-e", script, out: File::NULL, err: File::NULL)
  end
end

test "run fails when example fails in isolated project" do
  lib = File.join(File.expand_path("..", __dir__), "lib")
  Dir.mktmpdir do |dir|
    verity_dir = File.join(dir, "verity")
    FileUtils.mkdir_p(verity_dir)
    File.write(File.join(verity_dir, "bad_test.rb"), <<~RUBY)
      test "bad" do
        assert false
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
        exit(Verity.run(worker_id: 2) ? 1 : 0)
      end
    RUBY

    assert system(RbConfig.ruby, "-I#{lib}", "-e", script, out: File::NULL, err: File::NULL)
  end
end

test "run succeeds with no matching files" do
  lib = File.join(File.expand_path("..", __dir__), "lib")
  Dir.mktmpdir do |dir|
    FileUtils.mkdir_p(File.join(dir, "verity"))

    script = <<~RUBY
      require "verity"
      Dir.chdir(#{dir.inspect}) do
        Verity.reset_configuration!
        Verity.configure do |c|
          c.test_globs = ["verity/does_not_exist/**/*_test.rb"]
          c.manifest_path = ":memory:"
        end
        exit(Verity.run ? 0 : 1)
      end
    RUBY

    assert system(RbConfig.ruby, "-I#{lib}", "-e", script, out: File::NULL, err: File::NULL)
  end
end

test "load_discovery populates registry in isolated project" do
  lib = File.join(File.expand_path("..", __dir__), "lib")
  Dir.mktmpdir do |dir|
    FileUtils.mkdir_p(File.join(dir, "verity", "nested"))
    File.write(File.join(dir, "verity", "nested", "one_test.rb"), <<~RUBY)
      test "one" do
        assert true
      end
    RUBY

    script = <<~RUBY
      require "verity"
      Dir.chdir(#{dir.inspect}) do
        Verity.reset_configuration!
        Verity.configure { |c| c.test_globs = ["verity/**/*_test.rb"] }
        Verity.load_discovery!
        exit(Verity::Registry.all.size == 1 && Verity::Registry.all.first.description == "one" ? 0 : 1)
      end
    RUBY

    assert system(RbConfig.ruby, "-I#{lib}", "-e", script, out: File::NULL, err: File::NULL)
  end
end

test "run rejects worker_count below one" do
  lib = File.join(File.expand_path("..", __dir__), "lib")
  Dir.mktmpdir do |dir|
    FileUtils.mkdir_p(File.join(dir, "verity"))

    script = <<~RUBY
      require "verity"
      Dir.chdir(#{dir.inspect}) do
        Verity.reset_configuration!
        Verity.configure do |c|
          c.test_globs = ["verity/**/*_test.rb"]
          c.worker_count = 0
        end
        begin
          Verity.run
        rescue ArgumentError => e
          exit(e.message.match?(/worker_count/) ? 0 : 1)
        end
        exit(1)
      end
    RUBY

    assert system(RbConfig.ruby, "-I#{lib}", "-e", script, out: File::NULL, err: File::NULL)
  end
end

test "run rejects memory manifest with multiple workers" do
  if Process.respond_to?(:fork)
    lib = File.join(File.expand_path("..", __dir__), "lib")
    Dir.mktmpdir do |dir|
      verity_dir = File.join(dir, "verity")
      FileUtils.mkdir_p(verity_dir)
      File.write(File.join(verity_dir, "one_test.rb"), <<~RUBY)
        test "one" do
          assert true
        end
      RUBY

      script = <<~RUBY
        require "verity"
        Dir.chdir(#{dir.inspect}) do
          Verity.reset_configuration!
          Verity.configure do |c|
            c.manifest_path = ":memory:"
            c.worker_count = 2
          end
          begin
            Verity.run
          rescue ArgumentError => e
            exit(e.message.include?(":memory:") ? 0 : 1)
          end
          exit(1)
        end
      RUBY

      assert system(RbConfig.ruby, "-I#{lib}", "-e", script, out: File::NULL, err: File::NULL)
    end
  else
    assert true
  end
end

test "parallel workers share file manifest" do
  if Process.respond_to?(:fork)
    lib = File.join(File.expand_path("..", __dir__), "lib")
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

      script = <<~RUBY
        require "verity"
        Dir.chdir(#{dir.inspect}) do
          Verity.reset_configuration!
          Verity.configure do |c|
            c.manifest_path = #{db.inspect}
            c.test_globs = ["verity/**/*_test.rb"]
            c.worker_count = 4
          end
          exit(Verity.run ? 0 : 1)
        end
      RUBY

      assert system(RbConfig.ruby, "-I#{lib}", "-e", script, out: File::NULL, err: File::NULL)

      sqlite = SQLite3::Database.new(db)
      begin
        rows = sqlite.execute("SELECT status, COUNT(*) AS n FROM tests GROUP BY status").to_a
        assert_equal actual: rows, expected: [["passed", 15]]
      ensure
        sqlite.close
      end

      Dir.glob(File.join(dir, "manifest.db*")).each do |f|
        File.unlink(f)
      rescue Errno::ENOENT
      end
    end
  else
    assert true
  end
end

test "parallel workers propagate failure" do
  if Process.respond_to?(:fork)
    lib = File.join(File.expand_path("..", __dir__), "lib")
    Dir.mktmpdir do |dir|
      verity_dir = File.join(dir, "verity")
      FileUtils.mkdir_p(verity_dir)
      File.write(File.join(verity_dir, "bad_test.rb"), <<~RUBY)
        test "bad" do
          assert false
        end
      RUBY

      db = File.join(dir, "manifest.db")

      script = <<~RUBY
        require "verity"
        Dir.chdir(#{dir.inspect}) do
          Verity.reset_configuration!
          Verity.configure do |c|
            c.manifest_path = #{db.inspect}
            c.test_globs = ["verity/**/*_test.rb"]
            c.worker_count = 3
          end
          exit(Verity.run ? 1 : 0)
        end
      RUBY

      assert system(RbConfig.ruby, "-I#{lib}", "-e", script, out: File::NULL, err: File::NULL)

      Dir.glob(File.join(dir, "manifest.db*")).each do |f|
        File.unlink(f)
      rescue Errno::ENOENT
      end
    end
  else
    assert true
  end
end
