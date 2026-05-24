# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe "Verity.build_reporter (mirror of verity/build_reporter_test.rb)" do
  it "instantiates documentation / doc shortcuts" do
    Verity.configure { |c| c.reporter = Verity.build_reporter("documentation") }
    expect(Verity.configuration.reporter).to be_a(Verity::Reporters::DocumentationReporter)
  end

  it "instantiates colored, dots, and null aliases" do
    Verity.configure { |c| c.reporter = Verity.build_reporter("colored") }
    expect(Verity.configuration.reporter).to be_a(Verity::Reporters::ColoredDotsReporter)

    Verity.configure { |c| c.reporter = Verity.build_reporter("dots") }
    expect(Verity.configuration.reporter).to be_a(Verity::Reporters::DotsReporter)

    Verity.configure { |c| c.reporter = Verity.build_reporter("null") }
    expect(Verity.configuration.reporter).to be_a(Verity::Reporters::NullReporter)
  end

  it "raises on blank specs" do
    expect { Verity.build_reporter("   ") }.to raise_error(ArgumentError)
  end

  it "raises on unknown built-in tokens" do
    expect { Verity.build_reporter("fancy") }.to raise_error(ArgumentError, /unknown reporter/)
  end

  it "loads a custom reporter from path:class" do
    Dir.mktmpdir do |tmp|
      path = File.join(tmp, "custom_rep.rb")
      File.write(path, <<~RUBY)
        class TmpDogfoodCustomReporterXYZ
          include Verity::Reporter
        end
      RUBY

      reporter = Verity.build_reporter("#{path}:TmpDogfoodCustomReporterXYZ")
      expect(reporter).to be_a(TmpDogfoodCustomReporterXYZ)
    end
  end
end
