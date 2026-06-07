# frozen_string_literal: true

require "rails/generators/base"

module Verity
  module Generators
    # Public: `bin/rails generate verity:install`
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Install Verity helper, binstub, and sample test under test/verity/"

      def copy_verity_helper
        template "verity_helper.rb.tt", "test/verity_helper.rb"
      end

      def copy_binstub
        template "bin/verity.tt", "bin/verity"
        chmod "bin/verity", 0o755, verbose: false
      end

      def copy_sample_test
        empty_directory "test/verity"
        template "test/verity/sample_test.rb.tt", "test/verity/sample_test.rb"
      end

      def update_gitignore
        return unless File.exist?(".gitignore")

        manifest_entry = "tmp/verity_manifest.db"
        return if File.read(".gitignore").include?(manifest_entry)

        append_file ".gitignore" do
          <<~ENTRY

            # Verity SQLite manifest (see test/verity_helper.rb)
            #{manifest_entry}
          ENTRY
        end
      end
    end
  end
end
