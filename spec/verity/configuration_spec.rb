# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "etc"

RSpec.describe Verity::Configuration do
  subject(:config) { Verity::Configuration.new }

  describe "defaults" do
    it "sets manifest_path to verity/manifest.db" do
      expect(config.manifest_path).to eq("verity/manifest.db")
    end

    it "sets test_globs to verity/**/*_test.rb" do
      expect(config.test_globs).to eq(["verity/**/*_test.rb"])
    end

    it "sets worker_count to :cpus" do
      expect(config.worker_count).to eq(:cpus)
    end

    it "sets test_order to :random" do
      expect(config.test_order).to eq(:random)
    end

    it "sets shuffle_seed to nil" do
      expect(config.shuffle_seed).to be_nil
    end

    it "sets location_filters to []" do
      expect(config.location_filters).to eq([])
    end

    it "defaults reporter to ColoredDotsReporter" do
      expect(config.reporter).to be_a(Verity::Reporters::ColoredDotsReporter)
    end
  end

  describe "Verity.configure" do
    it "overrides values via the block" do
      reporter = Verity::Reporters::NullReporter.new
      Verity.configure do |c|
        c.manifest_path = "/tmp/test.db"
        c.test_globs = ["spec/**/*_spec.rb"]
        c.worker_count = 4
        c.reporter = reporter
      end

      cfg = Verity.configuration
      expect(cfg.manifest_path).to eq("/tmp/test.db")
      expect(cfg.test_globs).to eq(["spec/**/*_spec.rb"])
      expect(cfg.worker_count).to eq(4)
      expect(cfg.reporter).to equal(reporter)
    end
  end

  describe "#resolved_worker_count" do
    it "returns an integer when worker_count is an integer" do
      config.worker_count = 3
      expect(config.resolved_worker_count).to eq(3)
    end

    it "resolves :cpus to Etc.nprocessors" do
      config.worker_count = :cpus
      expect(config.resolved_worker_count).to eq([Etc.nprocessors, 1].max)
    end

    it "resolves :cpu to Etc.nprocessors" do
      config.worker_count = :cpu
      expect(config.resolved_worker_count).to eq([Etc.nprocessors, 1].max)
    end

    it 'resolves "cpus" to Etc.nprocessors' do
      config.worker_count = "cpus"
      expect(config.resolved_worker_count).to eq([Etc.nprocessors, 1].max)
    end

    it 'resolves "cpu" to Etc.nprocessors' do
      config.worker_count = "cpu"
      expect(config.resolved_worker_count).to eq([Etc.nprocessors, 1].max)
    end

    it "raises ArgumentError for an invalid value" do
      config.worker_count = :bogus
      expect { config.resolved_worker_count }.to raise_error(ArgumentError, /worker_count/)
    end

    it "raises ArgumentError for zero" do
      config.worker_count = 0
      expect { config.resolved_worker_count }.to raise_error(ArgumentError, /must be >= 1/)
    end
  end

  describe "#memory_manifest?" do
    it "returns true for :memory:" do
      config.manifest_path = ":memory:"
      expect(config.memory_manifest?).to be true
    end

    it "returns false for a file path" do
      config.manifest_path = "/tmp/manifest.db"
      expect(config.memory_manifest?).to be false
    end
  end

  describe "#test_files" do
    it "expands globs to matching files" do
      Dir.mktmpdir do |dir|
        sub = File.join(dir, "verity")
        Dir.mkdir(sub)
        f1 = File.join(sub, "alpha_test.rb")
        f2 = File.join(sub, "beta_test.rb")
        f3 = File.join(sub, "helper.rb")
        [f1, f2, f3].each { |f| File.write(f, "# test") }

        config.test_globs = [File.join(dir, "verity/**/*_test.rb")]
        result = config.test_files

        expect(result).to include(f1, f2)
        expect(result).not_to include(f3)
        expect(result).to eq(result.sort)
      end
    end

    it "returns an empty array when nothing matches" do
      config.test_globs = ["nonexistent_dir/**/*_test.rb"]
      expect(config.test_files).to eq([])
    end
  end
end
