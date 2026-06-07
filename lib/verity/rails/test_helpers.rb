# frozen_string_literal: true

module Verity
  module Rails
    # Public: Mixes common Rails test helpers into top-level Verity test files.
    module TestHelpers
      class << self
        # Internal: Include available helper modules on Object and register cleanup.
        def apply!
          helpers = build_helper_module
          return unless helpers

          Object.include(helpers)
          Verity::Rails.register_dsl_extension!(helpers)
          register_cleanup!
        end

        private

        def build_helper_module
          parts = []
          parts << ActiveSupport::Testing::TimeHelpers if defined?(ActiveSupport::Testing::TimeHelpers)
          parts << ActiveJob::TestHelper if defined?(ActiveJob::TestHelper)
          parts << ActionMailer::TestHelper if defined?(ActionMailer::TestHelper)
          return nil if parts.empty?

          ActiveJob::Base.queue_adapter = :test if defined?(ActiveJob::Base)

          Module.new do
            parts.each { |part| include part }
          end
        end

        def register_cleanup!
          Verity.after_test do
            travel_back if respond_to?(:travel_back, true)
            clear_enqueued_jobs if respond_to?(:clear_enqueued_jobs, true)
            ActionMailer::Base.deliveries.clear if defined?(ActionMailer::Base)
          end
        end
      end
    end
  end
end
