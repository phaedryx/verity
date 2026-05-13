# frozen_string_literal: true

module Verity
  class Runner
    Result = Data.define(:test, :status, :error)

    def initialize(reporter: nil)
      @reporter = reporter || Verity.configuration.reporter
    end

    def run(tests = Registry.all)
      run_worker(tests, worker_id: 0)
    end

    def run_manifest(manifest, worker_id:)
      Verity.hooks[:before_worker_start].each(&:call)

      @reporter.on_run_start(total: manifest.example_count, worker_id: worker_id)

      results = []
      while (claimed = manifest.claim_next(worker_id))
        test = Registry.find(claimed.fingerprint)
        unless test
          err = RuntimeError.new(
            "Test fingerprint not in Registry (load files before replace_tests): #{claimed.fingerprint}"
          )
          manifest.record_error(claimed.fingerprint, err)
          result = Result.new(test: synthetic_test_from_claim(claimed), status: :error, error: err)
          results << result
          @reporter.on_test_complete(result: result, worker_id: worker_id)
          next
        end

        result = run_with_hooks(test)
        results << result
        @reporter.on_test_complete(result: result, worker_id: worker_id)

        case result.status
        when :pass  then manifest.record_pass(test.fingerprint)
        when :fail  then manifest.record_failure(test.fingerprint, result.error)
        when :error then manifest.record_error(test.fingerprint, result.error)
        end
      end

      Registry.all.select { Verity.skipped?(_1) }.each do |t|
        @reporter.on_test_complete(
          result: Result.new(test: t, status: :skip, error: nil),
          worker_id: worker_id
        )
      end

      without_skip = Registry.all.reject { Verity.skipped?(_1) }
      skipped = Registry.all.count { Verity.skipped?(_1) }
      focus = Verity.focus_filter_active?(without_skip)

      @reporter.on_run_finish(
        summary: build_summary(results, skipped: skipped, focus: focus),
        worker_id: worker_id
      )
      results.all? { |r| r.status == :pass }
    end

    private

    def run_worker(tests, worker_id:)
      without_skip = tests.reject { Verity.skipped?(_1) }
      list =
        if without_skip.any? { Verity.focus_tag?(_1) }
          without_skip.select { Verity.focus_tag?(_1) }
        else
          without_skip
        end

      skipped = tests.count { Verity.skipped?(_1) }
      focus = Verity.focus_filter_active?(without_skip)

      @reporter.on_run_start(total: list.size, worker_id: worker_id)

      results = []
      list.each do |t|
        r = run_with_hooks(t)
        results << r
        @reporter.on_test_complete(result: r, worker_id: worker_id)
      end

      tests.select { Verity.skipped?(_1) }.each do |t|
        r = Result.new(test: t, status: :skip, error: nil)
        @reporter.on_test_complete(result: r, worker_id: worker_id)
      end

      @reporter.on_run_finish(
        summary: build_summary(results, skipped: skipped, focus: focus),
        worker_id: worker_id
      )
      results.all? { |r| r.status == :pass }
    end

    def build_summary(results, skipped:, focus:)
      {
        total: results.size,
        passed: results.count { |r| r.status == :pass },
        failed: results.count { |r| r.status == :fail },
        errored: results.count { |r| r.status == :error },
        skipped: skipped,
        focus: focus
      }
    end

    def synthetic_test_from_claim(claimed)
      Test.new(
        fingerprint: claimed.fingerprint,
        description: claimed.description,
        tags: claimed.tags.map(&:to_sym),
        timeout: claimed.timeout,
        requires: claimed.requires.map(&:to_sym),
        resources: claimed.resources.transform_keys(&:to_sym),
        file: claimed.file,
        line: claimed.line,
        fn: -> {},
        group_path: [],
        inherited_group_tags: []
      )
    end

    def run_with_hooks(test)
      result = nil
      begin
        Verity.hooks[:before_test].each(&:call)
        result = execute(test)
      rescue => e
        result = Result.new(test:, status: :error, error: e)
      ensure
        Verity.hooks[:after_test].each(&:call)
      end
      result
    end

    def execute(test)
      test.fn.call
      Result.new(test:, status: :pass, error: nil)
    rescue AssertionError => e
      Result.new(test:, status: :fail, error: e)
    rescue => e
      Result.new(test:, status: :error, error: e)
    end
  end
end
