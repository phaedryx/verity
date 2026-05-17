# frozen_string_literal: true

require "verity"

Dir[File.expand_path("support/**/*.rb", __dir__)].sort.each { |f| require f }

RSpec.configure do |config|
  config.include ReporterSpecHelpers
  config.before(:each) do
    Verity::Registry.clear
    Verity.reset_configuration!
    Verity.clear_group_stack!
    Verity.hooks.each_value(&:clear)
  end
end
