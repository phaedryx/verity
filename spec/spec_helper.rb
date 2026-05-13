# frozen_string_literal: true

require "verity"

RSpec.configure do |config|
  config.before(:each) do
    Verity::Registry.clear
    Verity.reset_configuration!
    Verity.clear_group_stack!
    Verity.hooks.each_value(&:clear)
  end
end
