# frozen_string_literal: true

# Shared setup for Minitest suites (no ivars — call from the top of each test).
module VerityTestHelper
  def reset_verity_process_state!
    Verity.reset_configuration!
    Verity::Registry.clear
    Verity.hooks.each_value(&:clear)
    Verity.resource_resolvers.clear
    Verity.configure { |c| c.test_order = :fingerprint } # quiet, deterministic Minitest runs
  end

  def reset_verity_configuration_only!
    Verity.reset_configuration!
  end
end
