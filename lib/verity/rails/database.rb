# frozen_string_literal: true

module Verity
  module Rails
    # Internal: ActiveRecord connection lifecycle for forked workers and
    # transactional test isolation.
    module Database
      class << self
        # Internal: Register hooks from Configuration.
        def apply!
          cfg = Verity::Rails.configuration
          register_per_worker_hook! if cfg.per_worker_database
          register_reconnect_hook! if cfg.reconnect_after_fork
          register_transactional_hooks! if cfg.transactional_tests
        end

        # Public: Disconnect every connection pool (call after fork, before work).
        def disconnect_all!
          return unless active_record?

          handler = base.connection_handler
          if handler.respond_to?(:clear_all_connections!)
            handler.clear_all_connections!
          else
            handler.clear_active_connections!
          end
        end

        # Public: Re-establish the test database connection (respects
        # ENV["TEST_ENV_NUMBER"] when set).
        def establish_test_connection!
          return unless active_record?

          env = defined?(::Rails) ? ::Rails.env.to_sym : :test
          base.establish_connection(env)
        end

        # Public: Set TEST_ENV_NUMBER and reconnect for a parallel worker.
        #
        # worker_id - Integer worker index from the Verity runner.
        def setup_per_worker!(worker_id)
          ENV["TEST_ENV_NUMBER"] = worker_id.zero? ? "" : worker_id.to_s
          disconnect_all!
          establish_test_connection!
        end

        # Public: Begin a joinable:false transaction on the primary connection.
        # Also pins all connection pools so integration test threads reuse the
        # same connection (mirrors ActiveRecord::TestFixtures behaviour).
        def begin_test_transaction
          return unless active_record?

          pin_all_pools!
          connection = base.connection
          return if connection.open_transactions.positive?

          connection.begin_transaction(joinable: false)
        end

        # Public: Roll back the outer test transaction when one is open.
        def rollback_test_transaction
          return unless active_record?

          connection = base.connection
          connection.rollback_transaction if connection.open_transactions.positive?
        ensure
          unpin_all_pools!
        end

        private

        def active_record?
          defined?(ActiveRecord::Base)
        end

        # Internal: Pin every connection pool to the current thread so that
        # integration test threads share the same connection as the test thread.
        # No-ops when the pool API is not available (older Rails / test doubles).
        def pin_all_pools!
          return unless active_record?

          handler = base.connection_handler
          return unless handler.respond_to?(:connection_pool_list)

          handler.connection_pool_list.each do |pool|
            pool.lock_thread = Thread.current if pool.respond_to?(:lock_thread=)
          end
        end

        # Internal: Release the thread pin on every connection pool.
        def unpin_all_pools!
          return unless active_record?

          handler = base.connection_handler
          return unless handler.respond_to?(:connection_pool_list)

          handler.connection_pool_list.each do |pool|
            pool.lock_thread = nil if pool.respond_to?(:lock_thread=)
          end
        end

        def base
          ActiveRecord::Base
        end

        def register_per_worker_hook!
          Verity.before_worker_start do |worker_id|
            setup_per_worker!(worker_id)
          end
        end

        def register_reconnect_hook!
          Verity.before_worker_start do |_worker_id|
            next if Verity::Rails.configuration.per_worker_database

            disconnect_all!
            establish_test_connection!
          end
        end

        def register_transactional_hooks!
          Verity.before_test { begin_test_transaction }
          Verity.after_test { rollback_test_transaction }
        end
      end
    end
  end
end
