# frozen_string_literal: true

require "spec_helper"

RSpec.describe Verity::Manifest do
  def make_test(description, fingerprint: nil)
    fp = fingerprint || "fp_#{description.gsub(/\s+/, "_")}:abcdef0123456789"
    Verity::Test.new(
      fingerprint: fp,
      description: description,
      tags: [:unit],
      timeout: 5.0,
      requires: [:db],
      resources: { cpu: 1 },
      file: __FILE__,
      line: __LINE__,
      fn: -> {},
      group_path: ["Suite"],
      inherited_group_tags: []
    )
  end

  let(:manifest) { Verity::Manifest.open(":memory:") }
  after { manifest.close }

  describe "#migrate!" do
    it "creates the tests table" do
      manifest.migrate!
      tables = manifest.db.execute("SELECT name FROM sqlite_master WHERE type='table'").flatten
      expect(tables).to include("tests")
    end

    it "is idempotent" do
      manifest.migrate!
      expect { manifest.migrate! }.not_to raise_error
    end
  end

  describe "#replace_tests" do
    before { manifest.migrate! }

    it "inserts tests as pending rows" do
      t1 = make_test("alpha")
      t2 = make_test("beta")
      manifest.replace_tests([t1, t2])

      count = manifest.db.get_first_value("SELECT COUNT(*) FROM tests").to_i
      expect(count).to eq(2)
    end

    it "replaces previous contents" do
      manifest.replace_tests([make_test("first")])
      manifest.replace_tests([make_test("second")])

      count = manifest.db.get_first_value("SELECT COUNT(*) FROM tests").to_i
      expect(count).to eq(1)
    end
  end

  describe "#claim_next" do
    before { manifest.migrate! }

    it "returns a pending test and marks it running" do
      t = make_test("claimable")
      manifest.replace_tests([t])

      claimed = manifest.claim_next(0)
      expect(claimed).not_to be_nil
      expect(claimed.fingerprint).to eq(t.fingerprint)
      expect(claimed.status).to eq(:running)
    end

    it "returns nil when no pending tests remain" do
      manifest.replace_tests([])
      expect(manifest.claim_next(0)).to be_nil
    end

    it "claims tests one at a time" do
      t1 = make_test("first", fingerprint: "aaa:abcdef0123456789")
      t2 = make_test("second", fingerprint: "bbb:abcdef0123456789")
      manifest.replace_tests([t1, t2])

      first = manifest.claim_next(0)
      second = manifest.claim_next(0)
      third = manifest.claim_next(0)

      expect(first).not_to be_nil
      expect(second).not_to be_nil
      expect(third).to be_nil
    end
  end

  describe "#record_pass" do
    before { manifest.migrate! }

    it "updates status to passed" do
      t = make_test("passing")
      manifest.replace_tests([t])
      manifest.claim_next(0)

      manifest.record_pass(t.fingerprint)
      status = manifest.db.get_first_value("SELECT status FROM tests WHERE fingerprint = ?", t.fingerprint)
      expect(status).to eq("passed")
    end
  end

  describe "#record_failure" do
    before { manifest.migrate! }

    it "updates status to failed with failure info" do
      t = make_test("failing")
      manifest.replace_tests([t])
      manifest.claim_next(0)

      error = Verity::AssertionError.new("bad assertion")
      manifest.record_failure(t.fingerprint, error)

      row = manifest.db.get_first_row("SELECT status, failure FROM tests WHERE fingerprint = ?", t.fingerprint)
      expect(row[0]).to eq("failed")

      failure = JSON.parse(row[1])
      expect(failure["class"]).to eq("Verity::AssertionError")
      expect(failure["message"]).to eq("bad assertion")
    end
  end

  describe "#record_error" do
    before { manifest.migrate! }

    it "updates status to errored with failure info" do
      t = make_test("erroring")
      manifest.replace_tests([t])
      manifest.claim_next(0)

      error = RuntimeError.new("kaboom")
      manifest.record_error(t.fingerprint, error)

      status = manifest.db.get_first_value("SELECT status FROM tests WHERE fingerprint = ?", t.fingerprint)
      expect(status).to eq("errored")
    end
  end

  describe "#count_by_status" do
    before { manifest.migrate! }

    it "returns correct counts" do
      t1 = make_test("p", fingerprint: "aaa:abcdef0123456789")
      t2 = make_test("f", fingerprint: "bbb:abcdef0123456789")
      t3 = make_test("e", fingerprint: "ccc:abcdef0123456789")
      manifest.replace_tests([t1, t2, t3])

      manifest.claim_next(0)
      manifest.record_pass(t1.fingerprint)

      manifest.claim_next(0)
      manifest.record_failure(t2.fingerprint, StandardError.new("fail"))

      manifest.claim_next(0)
      manifest.record_error(t3.fingerprint, RuntimeError.new("err"))

      counts = manifest.count_by_status
      expect(counts["passed"]).to eq(1)
      expect(counts["failed"]).to eq(1)
      expect(counts["errored"]).to eq(1)
    end
  end

  describe "#failures_for_report" do
    before { manifest.migrate! }

    it "returns failed and errored rows" do
      t1 = make_test("pass", fingerprint: "aaa:abcdef0123456789")
      t2 = make_test("fail", fingerprint: "bbb:abcdef0123456789")
      t3 = make_test("error", fingerprint: "ccc:abcdef0123456789")
      manifest.replace_tests([t1, t2, t3])

      manifest.claim_next(0)
      manifest.record_pass(t1.fingerprint)

      manifest.claim_next(0)
      manifest.record_failure(t2.fingerprint, StandardError.new("oops"))

      manifest.claim_next(0)
      manifest.record_error(t3.fingerprint, RuntimeError.new("boom"))

      rows = manifest.failures_for_report
      expect(rows.size).to eq(2)
      statuses = rows.map { _1[:status] }
      expect(statuses).to contain_exactly(:failed, :errored)
    end

    it "returns empty array when all pass" do
      t = make_test("ok")
      manifest.replace_tests([t])
      manifest.claim_next(0)
      manifest.record_pass(t.fingerprint)

      expect(manifest.failures_for_report).to eq([])
    end
  end

  describe "#example_count" do
    before { manifest.migrate! }

    it "returns the total number of rows" do
      tests = (1..5).map { |i| make_test("test_#{i}", fingerprint: "fp#{i}:abcdef0123456789") }
      manifest.replace_tests(tests)
      expect(manifest.example_count).to eq(5)
    end
  end
end
