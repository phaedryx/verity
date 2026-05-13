# frozen_string_literal: true

require "spec_helper"

RSpec.describe Verity::Runner do
  def make_test(description, tags: [], fn: -> {})
    Verity::Test.new(
      fingerprint: "fp_#{description.gsub(/\s+/, "_")}:abcdef0123456789",
      description: description,
      tags: tags,
      timeout: nil,
      requires: [],
      resources: {},
      file: __FILE__,
      line: __LINE__,
      fn: fn,
      group_path: [],
      inherited_group_tags: []
    )
  end

  def register(*tests)
    tests.each { |t| Verity::Registry.register(t) }
  end

  describe ".new" do
    it "uses the config reporter by default" do
      reporter = Verity::Reporters::TestReporter.new
      Verity.configure { |c| c.reporter = reporter }

      runner = Verity::Runner.new
      passing = make_test("passing")
      register(passing)
      runner.run([passing])

      expect(reporter.test_completes.size).to eq(1)
    end

    it "accepts a custom reporter" do
      custom = Verity::Reporters::TestReporter.new
      runner = Verity::Runner.new(reporter: custom)
      passing = make_test("passing")
      register(passing)
      runner.run([passing])

      expect(custom.test_completes.size).to eq(1)
    end
  end

  describe "#run" do
    it "returns true when all tests pass" do
      reporter = Verity::Reporters::TestReporter.new
      runner = Verity::Runner.new(reporter: reporter)

      t1 = make_test("pass1")
      t2 = make_test("pass2")
      register(t1, t2)

      expect(runner.run([t1, t2])).to be true
      expect(reporter.test_completes.map { _1[:status] }).to all(eq(:pass))
    end

    it "returns false when a test fails" do
      reporter = Verity::Reporters::TestReporter.new
      runner = Verity::Runner.new(reporter: reporter)

      failing = make_test("failing", fn: -> { raise Verity::AssertionError, "nope" })
      register(failing)

      expect(runner.run([failing])).to be false
      expect(reporter.test_completes.first[:status]).to eq(:fail)
    end

    it "returns false when a test errors" do
      reporter = Verity::Reporters::TestReporter.new
      runner = Verity::Runner.new(reporter: reporter)

      erroring = make_test("erroring", fn: -> { raise RuntimeError, "boom" })
      register(erroring)

      expect(runner.run([erroring])).to be false
      expect(reporter.test_completes.first[:status]).to eq(:error)
    end

    it "reports skipped tests" do
      reporter = Verity::Reporters::TestReporter.new
      runner = Verity::Runner.new(reporter: reporter)

      skipped = make_test("skipped", tags: [:skip])
      register(skipped)

      runner.run([skipped])
      statuses = reporter.test_completes.map { _1[:status] }
      expect(statuses).to include(:skip)
    end
  end

  describe "#run_manifest" do
    it "claims and runs tests from a manifest" do
      reporter = Verity::Reporters::TestReporter.new
      runner = Verity::Runner.new(reporter: reporter)

      t1 = make_test("manifest_pass")
      register(t1)

      manifest = Verity::Manifest.open(":memory:")
      manifest.migrate!
      manifest.replace_tests([t1])

      result = runner.run_manifest(manifest, worker_id: 0)
      manifest.close

      expect(result).to be true
      expect(reporter.run_starts.size).to eq(1)
      expect(reporter.test_completes.first[:status]).to eq(:pass)
      expect(reporter.run_finishes.size).to eq(1)
    end

    it "records failures in the manifest" do
      reporter = Verity::Reporters::TestReporter.new
      runner = Verity::Runner.new(reporter: reporter)

      failing = make_test("manifest_fail", fn: -> { raise Verity::AssertionError, "bad" })
      register(failing)

      manifest = Verity::Manifest.open(":memory:")
      manifest.migrate!
      manifest.replace_tests([failing])

      result = runner.run_manifest(manifest, worker_id: 0)

      expect(result).to be false
      counts = manifest.count_by_status
      expect(counts["failed"]).to eq(1)
      manifest.close
    end
  end
end
