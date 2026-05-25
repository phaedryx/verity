# frozen_string_literal: true

# Triple suite (compare / redundant proof): verity/skip_tag_test.rb · spec/verity/skip_tag_spec.rb

require "minitest/autorun"
require "fileutils"
require_relative "../lib/verity"
require_relative "verity_test_helper"

class SkipTagTest < Minitest::Test
  include VerityTestHelper

  def test_skipped_tests_omitted_from_runnable_list
    reset_verity_process_state!
    t_run = Verity::Test.new(
      fingerprint: "a.rb:aaaaaaaaaaaaaaaa",
      description: "runs",
      tags: [],
      timeout: nil,
      requires: [],
      resources: {},
      file: "a.rb",
      line: 1,
      fn: -> {},
      group_path: [],
      inherited_group_tags: [], group_scopes: []
    )
    t_skip = Verity::Test.new(
      fingerprint: "b.rb:bbbbbbbbbbbbbbbb",
      description: "skipped",
      tags: [], skip: true,
      timeout: nil,
      requires: [],
      resources: {},
      file: "b.rb",
      line: 1,
      fn: -> {},
      group_path: [],
      inherited_group_tags: [], group_scopes: []
    )
    Verity::Registry.register(t_run)
    Verity::Registry.register(t_skip)

    assert Verity.skipped?(t_skip)
    refute Verity.skipped?(t_run)
    assert_equal [t_run], Verity.runnable_tests
  end

  def test_run_skips_tagged_examples
    reset_verity_process_state!
    ran = []
    t_ok = Verity::Test.new(
      fingerprint: "a.rb:aaaaaaaaaaaaaaaa",
      description: "ok",
      tags: [],
      timeout: nil,
      requires: [],
      resources: {},
      file: "a.rb",
      line: 1,
      fn: -> { ran << :ok },
      group_path: [],
      inherited_group_tags: [], group_scopes: []
    )
    t_skip = Verity::Test.new(
      fingerprint: "b.rb:bbbbbbbbbbbbbbbb",
      description: "nope",
      tags: [], skip: true,
      timeout: nil,
      requires: [],
      resources: {},
      file: "b.rb",
      line: 2,
      fn: -> { ran << :skip },
      group_path: [],
      inherited_group_tags: [], group_scopes: []
    )
    Verity::Registry.register(t_ok)
    Verity::Registry.register(t_skip)

    rep = Verity::Reporters::TestReporter.new
    assert Verity::Runner.new(reporter: rep).run([t_ok, t_skip])
    assert_equal [{ total: 1, worker_id: 0 }], rep.run_starts
    assert_equal [{ status: :pass, error: nil, worker_id: 0 }, { status: :skip, error: nil, worker_id: 0 }], rep.test_completes
    assert_equal 1, rep.run_finishes.size
    fin = rep.run_finishes.first
    assert_equal 0, fin[:worker_id]
    s = fin[:summary]
    assert_equal 1, s[:total]
    assert_equal 1, s[:passed]
    assert_equal 0, s[:failed]
    assert_equal 0, s[:errored]
    assert_equal 1, s[:skipped]
    refute s[:focus]
    assert_equal [:ok], ran
  end

  def test_verity_run_manifest_excludes_skipped
    reset_verity_process_state!
    Dir.mktmpdir do |dir|
      verity_dir = File.join(dir, "verity")
      FileUtils.mkdir_p(verity_dir)
      File.write(File.join(verity_dir, "t_test.rb"), <<~RUBY)
        test "one" do
          assert true
        end

        test "two", skip: true do
          assert false
        end
      RUBY

      Dir.chdir(dir) do
        Verity.configure do |c|
          c.test_globs = ["verity/**/*_test.rb"]
          c.manifest_path = ":memory:"
          c.worker_count = 1
        end

        assert Verity.run
        assert_equal 2, Verity::Registry.all.size
        assert_equal 1, Verity.runnable_tests.size
      end
    end
  end
end
