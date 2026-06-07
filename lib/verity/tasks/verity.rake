# frozen_string_literal: true

namespace :verity do
  desc "Run Verity tests (pass options after --, e.g. bin/rake verity -- -w 4 -t slow)"
  task run: :environment do
    require "verity/rails"
    status = Verity::Rails::Runner.run!(Verity::Rails::Runner.rake_argv)
    exit(status) if status != 0
  end
end

desc "Run Verity tests (shortcut for verity:run)"
task verity: "verity:run"
