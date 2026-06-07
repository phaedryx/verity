# frozen_string_literal: true

require "minitest/autorun"
require "rails/generators/test_case"
require "generators/verity/install/install_generator"

class InstallGeneratorTest < Rails::Generators::TestCase
  tests Verity::Generators::InstallGenerator
  destination File.join(Dir.tmpdir, "verity_install_generator_test")
  setup :prepare_destination

  def test_install_generator_creates_expected_files
    run_generator

    assert_file "test/verity_helper.rb", /Verity::Rails\.install!/
    assert_file "bin/verity", /Verity::CLI\.run/
    assert_file "test/verity/sample_test.rb", /sample Verity test/
    assert File.executable?(File.join(destination_root, "bin/verity"))
  end

  def test_install_generator_appends_gitignore_entry
    File.write(File.join(destination_root, ".gitignore"), "log/\n")

    run_generator

    assert_file ".gitignore", %r{tmp/verity_manifest\.db}
  end
end
