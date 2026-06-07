# frozen_string_literal: true

module Verity
  module Rails
    # Public: Load and access ActiveRecord YAML fixtures from Verity test files.
    module Fixtures
      class << self
        # Internal: Load configured fixture sets once per worker.
        def apply!
          sets = Verity::Rails.configuration.fixture_sets
          return if sets.nil? || (sets.respond_to?(:empty?) && sets.empty?)

          Verity.before_worker_start do |_worker_id|
            load!(sets)
          end
          Verity::Rails.apply_fixture_dsl!
        end

        # Public: Load fixture YAML into the database for the given sets.
        #
        # sets - :all or an Array of Symbol/String table names.
        def load!(sets)
          require_active_record_fixtures!
          table_names = resolve_table_names(sets)
          return if table_names.empty?

          ActiveRecord::FixtureSet.create_fixtures(resolved_fixture_path, table_names)
          @loaded_table_names = table_names.map(&:to_s)
        end

        # Public: Return the ActiveRecord model for a fixture label.
        #
        # set   - Symbol or String fixture set name (e.g. :users).
        # label - Symbol or String row label from the YAML (default :one).
        #
        # Returns an ActiveRecord model instance.
        def find(set, label = :one)
          require_active_record_fixtures!
          table = set.to_s
          model = model_class_for(table)
          id = ActiveRecord::FixtureSet.identify(label, table)
          model.find(id)
        end

        # Public: Table names loaded by the most recent #load!.
        def loaded_table_names
          @loaded_table_names || []
        end

        # Public: Directory used for YAML fixtures.
        def fixture_path
          Verity::Rails.configuration.fixture_path || default_fixture_path
        end

        private

        def require_active_record_fixtures!
          return if defined?(ActiveRecord::FixtureSet)

          raise LoadError,
                "ActiveRecord::FixtureSet is required for Verity::Rails fixtures " \
                "(add activerecord / rails to the test bundle)"
        end

        def resolved_fixture_path
          fixture_path
        end

        def default_fixture_path
          if defined?(::Rails)
            ::Rails.root.join("test/fixtures").to_s
          else
            File.expand_path("test/fixtures")
          end
        end

        def resolve_table_names(sets)
          if sets == :all
            Dir.children(resolved_fixture_path)
               .grep(/\.ya?ml\z/)
               .map { |f| File.basename(f, ".*") }
               .sort
          else
            Array(sets).map(&:to_s)
          end
        end

        def model_class_for(table)
          table.classify.constantize
        end
      end

      # Public: Adds users(:one)-style methods for each configured fixture set.
      module DSL
        class << self
          def apply!
            sets = Verity::Rails.configuration.fixture_sets
            return if sets.nil? || (sets.respond_to?(:empty?) && sets.empty?)

            table_names =
              if sets == :all
                Dir.children(Fixtures.fixture_path)
                   .grep(/\.ya?ml\z/)
                   .map { |f| File.basename(f, ".*") }
                   .sort
              else
                Array(sets).map(&:to_s)
              end

            mod = Module.new do
              table_names.each do |table|
                define_method(table.to_sym) do |label = :one|
                  Fixtures.find(table, label)
                end
              end
            end
            Object.include(mod)
            Verity::Rails.register_dsl_extension!(mod)
          end
        end
      end
    end
  end
end
