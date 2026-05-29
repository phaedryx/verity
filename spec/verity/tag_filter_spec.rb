# frozen_string_literal: true

require "spec_helper"
require "open3"
require "fileutils"
require "tmpdir"

RSpec.describe "tag_filter (triple suite twin of test/tag_filter_test.rb)" do
  let(:bin) { File.expand_path("../../bin/verity", __dir__) }

  it "runs only matching tags and applies exclude-tag via CLI" do
    Dir.mktmpdir do |tmp|
      vd = File.join(tmp, "verity")
      FileUtils.mkdir_p(vd)
      File.write(File.join(vd, "t_test.rb"), <<~RUBY)
        test "a", tags: [:slow] do
          assert true
        end
        test "b", tags: [:fast] do
          assert false
        end
      RUBY

      _out, err, st = Open3.capture3(RbConfig.ruby, bin, "-t", "slow", "--exclude-tag", "fast", chdir: tmp)
      expect(st.exitstatus).to eq(0), err
    end
  end

  it "verity.run honors included_tags in-process" do
    Verity.reset_configuration!
    Verity::Registry.clear
    Verity.configure do |c|
      c.test_order = :fingerprint
      c.included_tags = [:keep]
    end
    Object.new.extend(Verity::DSL).instance_eval do
      test "in", tags: [:keep] do
      end
      test "out" do
      end
    end
    expect(Verity.runnable_tests.map(&:description)).to eq(["in"])
  end
end
