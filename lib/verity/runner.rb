# frozen_string_literal: true

require "timeout"

module Verity
  # Public: Executes tests, fires reporter hooks, and records results back to
  # the manifest. A single Runner instance services one worker process.
  class Runner
    # Public: Immutable outcome of running a single test.
    #
    # test   - The Verity::Test that was executed.
    # status - Symbol :pass, :fail, :error, or :skip.
    # error  - Exception instance or nil.
    Result = Data.define(:test, :status, :error)

    # Public: Create a new Runner.
    #
    # reporter - Object implementing Verity::Reporter (default: from configuration).
    def initialize(reporter: nil)
      @reporter = reporter || Verity.configuration.reporter
    end

    # Public: Run a list of tests in-process without a manifest. Primarily
    # used for simple single-worker execution.
    #
    # tests - Array of Verity::Test (default: all registered tests).
    #
    # Returns true if every test passed.
    def run(tests = Registry.all)
      run_worker(tests, worker_id: 0)
    end

    CONFLICT_RETRY_INTERVAL = 0.05

    # Public: Claim and execute tests from a shared manifest until none remain.
    # Fires before_worker_start hooks, then loops claim_next until exhausted.
    # When resource resolvers are registered, builds a conflict exclusion list
    # before each claim and sleeps briefly when blocked by running tests.
    #
    # manifest  - A Verity::Manifest instance.
    # worker_id - Integer identifying this worker.
    #
    # Returns true if every executed test passed.
    def run_manifest(manifest, worker_id:)
      Verity.hooks[:before_worker_start].each(&:call)

      @reporter.on_run_start(total: manifest.example_count, worker_id: worker_id)

      results = []
      loop do
        claimed = next_claim(manifest, worker_id)
        if claimed == :blocked
          sleep CONFLICT_RETRY_INTERVAL
          next
        end
        break unless claimed

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

    # Returns the next ClaimedRow, nil when the queue is empty, or the symbol
    # :blocked when pending tests exist but all conflict with running tests.
    def next_claim(manifest, worker_id)
      return manifest.claim_next(worker_id) if Verity.resource_resolvers.empty?

      running_res = manifest.running_resources
      exclude = Verity.conflict_exclusion_list(running_res)
      claimed = manifest.claim_next(worker_id, exclude: exclude)
      return claimed if claimed
      exclude.empty? ? nil : :blocked
    end

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
        inherited_group_tags: [],
        group_scopes: []
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
      body = proc { test.fn.call }
      if (sec = timeout_seconds_for(test))
        Timeout.timeout(sec, TestTimeoutError, &body)
      else
        body.call
      end
      Result.new(test:, status: :pass, error: nil)
    rescue AssertionError => e
      Result.new(test:, status: :fail, error: e)
    rescue TestTimeoutError => e
      Result.new(test:, status: :error, error: e)
    rescue => e
      Result.new(test:, status: :error, error: e)
    end

    def timeout_seconds_for(test)
      Verity.validate_test_timeout!(test.timeout)
      return nil if test.timeout.nil?

      test.timeout.to_f
    end
  end
end
