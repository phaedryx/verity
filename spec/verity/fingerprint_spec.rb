# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Verity::Fingerprint do
  describe ".plan_file" do
    it "parses Ruby source and maps test lines to fingerprints" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "sample_test.rb")
        File.write(path, <<~RUBY)
          test "one" do
            assert true
          end

          test "two" do
            assert true
          end
        RUBY

        plan = Verity::Fingerprint.plan_file(path)
        expect(plan).to be_a(Hash)
        expect(plan.size).to eq(2)
        expect(plan[1]).to be_a(String)
        expect(plan[5]).to be_a(String)
        expect(plan[1]).not_to eq(plan[5])
      end
    end

    it "disambiguates duplicate bodies by appending line number" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "dup_test.rb")
        File.write(path, <<~RUBY)
          test "a" do
            assert true
          end

          test "b" do
            assert true
          end
        RUBY

        plan = Verity::Fingerprint.plan_file(path)
        plan.each_value do |fp|
          parts = fp.split(":")
          expect(parts.size).to be >= 3
        end
      end
    end

    it "returns an empty hash for unparseable content" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "bad.rb")
        File.write(path, "def foo(")

        plan = Verity::Fingerprint.plan_file(path)
        expect(plan).to eq({})
      end
    end
  end

  describe ".install_plan! / .clear_plan! / .lookup cycle" do
    it "installs a plan, enables lookup, and clears it" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "cycle_test.rb")
        File.write(path, <<~RUBY)
          test "hello" do
            assert true
          end
        RUBY

        Verity::Fingerprint.install_plan!(path)
        fp = Verity::Fingerprint.lookup(1)
        expect(fp).to be_a(String)
        expect(fp).not_to be_empty

        Verity::Fingerprint.clear_plan!
        expect(Verity::Fingerprint.lookup(1)).to be_nil
      end
    end
  end

  describe ".fallback_fingerprint" do
    it "returns a string in relative_path:hex format" do
      result = Verity::Fingerprint.fallback_fingerprint("/some/path/test.rb", 42)
      expect(result).to be_a(String)
      parts = result.split(":")
      expect(parts.last).to match(/\A[a-f0-9]{16}\z/)
    end

    it "is deterministic for the same inputs" do
      a = Verity::Fingerprint.fallback_fingerprint("/foo/bar.rb", 10)
      b = Verity::Fingerprint.fallback_fingerprint("/foo/bar.rb", 10)
      expect(a).to eq(b)
    end

    it "differs for different lines" do
      a = Verity::Fingerprint.fallback_fingerprint("/foo/bar.rb", 10)
      b = Verity::Fingerprint.fallback_fingerprint("/foo/bar.rb", 20)
      expect(a).not_to eq(b)
    end
  end
end
