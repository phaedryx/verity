# frozen_string_literal: true

require_relative "verity/version"
require_relative "verity/fingerprint"
require_relative "verity/reporter"
require_relative "verity/reporters/parallel_summary_reporter"
require_relative "verity/reporters/documentation_reporter"
require_relative "verity/reporters/dots_reporter"
require_relative "verity/reporters/colored_dots"
require_relative "verity/reporters/null_reporter"
require_relative "verity/reporters/test_reporter"
require_relative "verity/reporters/composite_reporter"
require_relative "verity/configuration"
require_relative "verity/assertions"
require_relative "verity/manifest"
require_relative "verity/runner"

module Verity
  # Public: Source location of an enclosing `group` block at registration time.
  GroupScope = Data.define(:title, :file, :line)

  # Public: Immutable value object representing a single registered test case.
  #
  # fingerprint          - String content-based identifier for the test body.
  # description          - String human-readable name supplied to the `test` DSL.
  # tags                 - Array of Symbols applied directly to the test.
  # timeout              - Numeric seconds (or nil); enforced by Runner with stdlib Timeout.
  # requires             - Array of Symbols naming shared preconditions.
  # resources            - Hash of keyword resources forwarded from `test`.
  # file                 - String absolute path of the source file.
  # line                 - Integer source line number.
  # fn                   - Proc (block) containing the test body.
  # group_path           - Frozen Array of Strings representing nested group titles.
  # inherited_group_tags - Frozen Array of Symbols from enclosing group tags.
  # group_scopes         - Frozen Array of GroupScope (enclosing groups, outer first).
  Test = Data.define(
    :fingerprint, :description, :tags, :timeout, :requires, :resources, :file, :line, :fn,
    :group_path, :inherited_group_tags, :group_scopes
  )

  # Public: Compute all tags that apply to a test, combining enclosing group
  # tags with the test's own tags (outer groups first).
  #
  # test - A Verity::Test instance.
  #
  # Returns an Array of Symbols.
  def self.effective_tags(test)
    Array(test.inherited_group_tags).map(&:to_sym) + Array(test.tags).map(&:to_sym)
  end

  # Public: Validate a value for Verity::Test#timeout.
  #
  # Allows +nil+ (no limit). Otherwise +timeout+ must be a finite Numeric
  # strictly greater than zero (+Complex+ is rejected).
  #
  # Raises ArgumentError when invalid.
  def self.validate_test_timeout!(timeout)
    return if timeout.nil?

    unless timeout.is_a?(Numeric) && !timeout.is_a?(Complex)
      raise ArgumentError,
            "test timeout must be nil or a positive finite Numeric (got #{timeout.class}: #{timeout.inspect})"
    end

    non_finite =
      (timeout.is_a?(Float) && !timeout.finite?) ||
      (timeout.respond_to?(:infinite?) && !timeout.infinite?.nil?)

    raise ArgumentError, "test timeout must be finite (got #{timeout.inspect})" if non_finite

    return if timeout > 0

    raise ArgumentError, "test timeout must be positive (got #{timeout.inspect})"
  end

  # Public: Check whether a test is tagged with :skip.
  #
  # test - A Verity::Test instance.
  #
  # Returns true if the test should be skipped.
  def self.skipped?(test) = effective_tags(test).include?(:skip)

  # Public: Check whether a test is tagged with :focus.
  #
  # test - A Verity::Test instance.
  #
  # Returns true if the test has the focus tag.
  def self.focus_tag?(test) = effective_tags(test).include?(:focus)

  # Public: Collect the tests that should actually execute. Skipped tests are
  # excluded; when any remaining test has :focus, only focused tests are kept.
  #
  # Returns an Array of Verity::Test.
  def self.runnable_tests
    base = Registry.all.reject { skipped?(_1) }
    base = if base.any? { focus_tag?(_1) }
      base.select { focus_tag?(_1) }
    else
      base
    end
    filter_by_location_filters(base)
  end

  # Public: Detect whether focus filtering narrowed the suite — at least one
  # candidate has :focus and at least one does not.
  #
  # candidates - Array of Verity::Test (already excluding skipped tests).
  #
  # Returns true when the suite is a strict focus-filtered subset.
  def self.focus_filter_active?(candidates)
    return false if candidates.empty?

    candidates.any? { focus_tag?(_1) } && candidates.any? { !focus_tag?(_1) }
  end

  # Internal: Keep tests that match any configured location filter (test line
  # or an enclosing group line). Paths compared via File.expand_path.
  #
  # tests - Array of Verity::Test (typically after skip/focus narrowing).
  #
  # Returns a filtered Array.
  def self.filter_by_location_filters(tests)
    filters = configuration.location_filters
    return tests if filters.nil? || filters.empty?

    matched = tests.select { |t| filters.any? { |pair| location_filter_match?(t, pair[0], pair[1]) } }
    if matched.empty? && !tests.empty?
      hint = filters.map { |p, l| "#{File.expand_path(p)}:#{l}" }.join(", ")
      warn "verity: no tests matched location filter (#{hint})"
    end
    matched
  end

  # Internal: True if (path, line) is this test's `test` line or a GroupScope line.
  def self.location_filter_match?(test, path, line)
    exp = File.expand_path(path)
    return true if File.expand_path(test.file) == exp && test.line == line

    test.group_scopes.any? { |g| File.expand_path(g.file) == exp && g.line == line }
  end

  # Internal: Push a group frame onto the current thread's group stack.
  # Called by DSL#group during test file loading.
  #
  # title - String title for the group.
  # tags  - Array of Symbols (default []).
  # file  - String absolute path of the `group` call site.
  # line  - Integer line of the `group` call.
  #
  # Returns the updated stack Array.
  def self.push_group(title, tags:, file:, line:)
    entry = {
      title: title.to_s,
      tags: Array(tags).map(&:to_sym),
      file: file,
      line: line
    }
    (Thread.current[:verity_group_stack] ||= []) << entry
  end

  # Internal: Pop the most recent group frame from the current thread's stack.
  #
  # Returns the removed Hash entry, or nil.
  def self.pop_group
    Thread.current[:verity_group_stack]&.pop
  end

  # Internal: Snapshot of nested group titles for the current thread, used
  # at registration time to capture a test's group ancestry.
  #
  # Returns a frozen Array of Strings.
  def self.group_path_for_registration
    stack = Thread.current[:verity_group_stack]
    return [].freeze if stack.nil? || stack.empty?

    stack.map { _1[:title] }.freeze
  end

  # Internal: Enclosing group source scopes for the current thread (outer first).
  #
  # Returns a frozen Array of GroupScope.
  def self.group_scopes_for_registration
    stack = Thread.current[:verity_group_stack]
    return [].freeze if stack.nil? || stack.empty?

    stack.map { |g| GroupScope.new(g[:title], g[:file], g[:line]) }.freeze
  end

  # Internal: Collect all tags from enclosing groups for the current thread,
  # flattened in nesting order (outermost first).
  #
  # Returns a frozen Array of Symbols.
  def self.inherited_group_tags_for_registration
    stack = Thread.current[:verity_group_stack]
    return [].freeze if stack.nil? || stack.empty?

    stack.flat_map { |g| g[:tags] }.freeze
  end

  # Internal: Reset the current thread's group stack to empty. Called before
  # loading each test file to prevent cross-file leakage.
  #
  # Returns an empty Array.
  def self.clear_group_stack!
    Thread.current[:verity_group_stack] = []
  end

  # Public: Resolve a reporter instance from a CLI or config string.
  #
  # Built-in names (case-insensitive): "documentation" ("doc"), "colored"
  # ("colored_dots"), "dots", "null" ("none", "silent"). Custom reporters
  # use the form "path/to/reporter.rb:ClassName".
  #
  # spec - String reporter name or "path:ClassName" pair.
  #
  # Examples
  #
  #   Verity.build_reporter("dots")
  #   # => #<Verity::Reporters::DotsReporter ...>
  #
  #   Verity.build_reporter("./my_reporter.rb:MyReporter")
  #   # => #<MyReporter ...>
  #
  # Returns an Object that includes Verity::Reporter.
  # Raises ArgumentError if the spec is blank or unrecognised.
  def self.build_reporter(spec)
    raise ArgumentError, "reporter name cannot be blank" if spec.nil? || spec.strip.empty?

    case spec.strip.downcase
    when "documentation", "doc"
      Reporters::DocumentationReporter.new($stdout)
    when "colored", "colored_dots"
      Reporters::ColoredDotsReporter.new($stdout)
    when "dots"
      Reporters::DotsReporter.new($stdout)
    when "null", "none", "silent"
      Reporters::NullReporter.new
    else
      reporter_from_path_and_class(spec.strip)
    end
  end

  def self.reporter_from_path_and_class(spec)
    raise ArgumentError, build_reporter_unknown_message(spec) unless spec.include?(":")

    path, cname = spec.split(":", 2)
    path = path.strip
    cname = cname.strip
    if path.empty? || cname.empty?
      raise ArgumentError, "custom reporter must be path/to.rb:ClassName (got #{spec.inspect})"
    end

    abs = File.expand_path(path)
    unless File.file?(abs)
      raise ArgumentError, "reporter file not found: #{abs}"
    end

    load abs
    cls = constantize_reporter_class(cname)
    unless cls.is_a?(Class) && cls.included_modules.include?(Reporter)
      raise ArgumentError, "#{cname} must be a class that includes Verity::Reporter (got #{cls.class})"
    end

    cls.new
  end
  private_class_method :reporter_from_path_and_class

  def self.constantize_reporter_class(cname)
    parts = cname.split("::")
    parts.shift if parts.first&.empty?
    raise ArgumentError, "invalid reporter class name #{cname.inspect}" if parts.empty? || parts.any?(&:empty?)

    parts.reduce(Object) { |mod, part| mod.const_get(part, false) }
  end
  private_class_method :constantize_reporter_class

  def self.build_reporter_unknown_message(spec)
    "unknown reporter #{spec.inspect}; use documentation, colored, dots, null, or path/to.rb:ClassName"
  end
  private_class_method :build_reporter_unknown_message

  # Internal: Global test registry. Tests are appended during file loading
  # and queried at run time by the Runner and manifest.
  module Registry
    @tests = []

    # Internal: Add a test to the global registry.
    #
    # test - A Verity::Test instance.
    #
    # Returns the updated Array.
    def self.register(test) = @tests << test

    # Internal: Return a shallow copy of all registered tests.
    #
    # Returns an Array of Verity::Test.
    def self.all = @tests.dup

    # Internal: Remove every registered test. Used before re-loading files.
    #
    # Returns an empty Array.
    def self.clear = @tests.clear

    # Internal: Look up a test by its fingerprint string.
    #
    # fingerprint - String fingerprint to match.
    #
    # Returns a Verity::Test or nil.
    def self.find(fingerprint) = @tests.find { |t| t.fingerprint == fingerprint }
  end

  # Public: Methods mixed into Object so that `test` and `group` are
  # available at the top level in test files.
  module DSL
    include Assertions

    # Public: Define a named group of tests. Groups may be nested and
    # contribute tags that are inherited by every enclosed test.
    #
    # title - String group name shown in reporter output.
    # tags  - Array of Symbols applied to all tests in this group (default []).
    # block - Block containing nested `test` and `group` calls.
    #
    # Raises ArgumentError if no block is given.
    def group(title, tags: [], &block)
      raise ArgumentError, "`group` requires a block" unless block

      loc = caller_locations(1, 1).first
      pushed = false
      Verity.push_group(title, tags: tags, file: loc.path, line: loc.lineno)
      pushed = true
      yield
    ensure
      Verity.pop_group if pushed
    end

    # Public: Register a single test case. The block is stored and executed
    # later by the Runner.
    #
    # description - String human-readable test name.
    # tags        - Array of Symbols (e.g. :focus, :skip) (default []).
    # timeout     - Numeric seconds or nil for no timeout (default nil). If set,
    #               must be a positive finite Numeric (+Complex+ and strings are rejected).
    # requires    - Array of Symbols naming shared preconditions (default []).
    # resources   - Hash of keyword arguments forwarded as resource metadata.
    # fn          - Block containing assertions and test logic.
    #
    # Returns the newly registered Verity::Test.
    def test(description, tags: [], timeout: nil, requires: [], **resources, &fn)
      Verity.validate_test_timeout!(timeout)
      location = caller_locations(1, 1).first
      file = location.path
      line = location.lineno
      fingerprint = Verity::Fingerprint.lookup(line) || Verity::Fingerprint.fallback_fingerprint(file, line)

      Verity::Registry.register(
        Verity::Test.new(
          fingerprint:,
          description:,
          tags:,
          timeout:,
          requires:,
          resources:,
          file:,
          line:,
          fn:,
          group_path: Verity.group_path_for_registration,
          inherited_group_tags: Verity.inherited_group_tags_for_registration,
          group_scopes: Verity.group_scopes_for_registration
        )
      )
    end
  end

  # Public: Register a callback invoked once per worker process before any
  # tests run (useful for DB setup, connection pooling, etc.).
  #
  # block - Proc to execute.
  #
  # Returns the updated callback Array.
  def self.before_worker_start(&block) = hooks[:before_worker_start] << block

  # Public: Register a callback invoked before each individual test.
  #
  # block - Proc to execute.
  #
  # Returns the updated callback Array.
  def self.before_test(&block) = hooks[:before_test] << block

  # Public: Register a callback invoked after each individual test.
  #
  # block - Proc to execute.
  #
  # Returns the updated callback Array.
  def self.after_test(&block) = hooks[:after_test] << block

  # Public: Declare a named resource with conflict rules for parallel
  # scheduling.
  #
  # name           - Symbol resource name.
  # conflicts_with - Conflict specification stored for the scheduler.
  #
  # Returns the updated resolvers Hash.
  def self.register_resource(name, conflicts_with:)
    resource_resolvers[name] = conflicts_with
  end

  # Public: Build the set of test fingerprints that must not be claimed because
  # they conflict with at least one currently-running test's resources.
  #
  # running_resources - Array of resource Hashes (string keys/values) from
  #                     Manifest#running_resources.
  # tests             - Array of Verity::Test to check (default: Registry.all).
  #
  # Returns an Array of fingerprint Strings. Returns [] when no resolvers are
  # registered or running_resources is empty (bypass fast-path).
  def self.conflict_exclusion_list(running_resources, tests: Registry.all)
    return [] if resource_resolvers.empty? || running_resources.empty?

    tests.select { |t| test_conflicts_with_running?(t.resources, running_resources) }
         .map(&:fingerprint)
  end

  def self.test_conflicts_with_running?(test_resources, running_resources)
    resource_resolvers.any? do |resource_type, resolver|
      mine = normalize_resource_value(
        test_resources[resource_type] || test_resources[resource_type.to_s]
      )
      next false if mine.nil? || mine.empty?

      running_resources.any? do |running_res|
        theirs = normalize_resource_value(
          running_res[resource_type.to_s] || running_res[resource_type]
        )
        next false if theirs.nil? || theirs.empty?

        resolver.call(mine, theirs)
      end
    end
  end
  private_class_method :test_conflicts_with_running?

  def self.normalize_resource_value(val)
    return nil if val.nil? || val == false

    Array(val).map(&:to_s)
  end
  private_class_method :normalize_resource_value

  # Internal: Lazily-initialised Hash of lifecycle hook Arrays keyed by
  # :before_worker_start, :before_test, and :after_test.
  #
  # Returns a Hash.
  def self.hooks
    @hooks ||= { before_worker_start: [], before_test: [], after_test: [] }
  end

  # Internal: Lazily-initialised Hash mapping resource names to their
  # conflict specifications.
  #
  # Returns a Hash.
  def self.resource_resolvers
    @resource_resolvers ||= {}
  end

  # Public: Discover and load all test files according to Configuration#test_globs.
  # Clears the registry, installs fingerprint plans, and loads each file.
  #
  # Returns nothing meaningful.
  def self.load_discovery!
    Registry.clear
    configuration.test_files.each do |path|
      clear_group_stack!
      abs = File.expand_path(path)
      Verity::Fingerprint.install_plan!(abs)
      begin
        load abs
      ensure
        Verity::Fingerprint.clear_plan!
      end
    end
  end

  # Internal: Runnable tests in coordinator dispatch order for the manifest
  # (fingerprint sort or random shuffle). Shuffle is used when test_order is
  # :random or when shuffle_seed is set. Auto-chosen seeds are printed to stderr
  # as a single line (the integer only).
  #
  # Returns Array of Verity::Test.
  def self.ordered_runnable_tests
    list = runnable_tests
    order = configuration.test_order
    unless %i[fingerprint random].include?(order)
      raise ArgumentError,
            "test_order must be :fingerprint or :random (got #{order.inspect})"
    end

    rng_seed = configuration.shuffle_seed
    use_random = order == :random || !rng_seed.nil?

    if use_random
      s = rng_seed
      if s.nil?
        s = Random.new_seed
        configuration.shuffle_seed = s
        warn s.to_s
      end
      list.shuffle(random: Random.new(s))
    else
      list.sort_by(&:fingerprint)
    end
  end
  private_class_method :ordered_runnable_tests

  # Public: Main entry point — discover tests, set up the manifest, and
  # execute. When worker_count > 1 the run forks child processes that each
  # claim work from a shared SQLite manifest.
  #
  # worker_id - Integer base worker id for single-process mode (default 0).
  #
  # Returns true if every test passed, false otherwise.
  # Raises ArgumentError if parallel mode uses a :memory: manifest.
  # Raises NotImplementedError if fork is unavailable for parallel mode.
  def self.run(worker_id: 0)
    load_discovery!

    workers = configuration.resolved_worker_count

    path = configuration.manifest_path
    if workers > 1
      if configuration.memory_manifest?
        raise ArgumentError,
              "manifest_path cannot be :memory: when worker_count > 1 (SQLite memory DBs are not shared across processes)"
      end
      unless Process.respond_to?(:fork)
        raise NotImplementedError, "Parallel workers require Kernel#fork (not available on this platform)"
      end

      sync_manifest!(path)
      pids = workers.times.map do |wid|
        fork do
          Verity.send(:run_manifest_child, path, worker_id: wid)
        end
      end
      ok = pids.all? do |pid|
        _, status = Process.wait2(pid)
        status.success?
      end

      manifest = Manifest.open(path)
      begin
        abandoned = manifest.reclaim_abandoned_running!
        ok &&= abandoned.zero?

        rep = configuration.reporter
        rep.on_run_start(total: manifest.example_count, worker_id: 0)

        manifest.each_parallel_replay_result do |result|
          rep.on_test_complete(result: result, worker_id: 0)
        end

        Registry.all.select { skipped?(_1) }.sort_by(&:fingerprint).each do |t|
          rep.on_test_complete(
            result: Runner::Result.new(test: t, status: :skip, error: nil),
            worker_id: 0
          )
        end

        skip_count = Registry.all.count { skipped?(_1) }
        counts = manifest.count_by_status.merge("skipped" => skip_count)
        problem_rows = manifest.failures_for_report
        rep.on_parallel_complete(counts: counts, problem_rows: problem_rows)
      ensure
        manifest.close
      end

      ok
    else
      manifest = Manifest.open(path)
      begin
        manifest.migrate!
        manifest.replace_tests(ordered_runnable_tests)
        Runner.new.run_manifest(manifest, worker_id:)
      ensure
        manifest.close
      end
    end
  end

  def self.sync_manifest!(path)
    manifest = Manifest.open(path)
    begin
      manifest.migrate!
      manifest.replace_tests(ordered_runnable_tests)
    ensure
      manifest.close
    end
  end
  private_class_method :sync_manifest!

  def self.run_manifest_child(path, worker_id:)
    manifest = Manifest.open(path)
    ok = false
    begin
      ok = Runner.new(reporter: Reporters::NullReporter.new).run_manifest(manifest, worker_id:)
    ensure
      manifest.close
    end
    exit(ok ? 0 : 1)
  end
  private_class_method :run_manifest_child
end

Object.include(Verity::DSL)
