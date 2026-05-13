# frozen_string_literal: true

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
  VERSION = "0.1.0"

  Test = Data.define(
    :fingerprint, :description, :tags, :timeout, :requires, :resources, :file, :line, :fn,
    :group_path, :inherited_group_tags
  )

  # Tags from enclosing `group ...(tags:)` blocks plus the test's own `tags:` (outer groups first).
  def self.effective_tags(test)
    Array(test.inherited_group_tags).map(&:to_sym) + Array(test.tags).map(&:to_sym)
  end

  def self.skipped?(test) = effective_tags(test).include?(:skip)

  def self.focus_tag?(test) = effective_tags(test).include?(:focus)

  def self.runnable_tests
    base = Registry.all.reject { skipped?(_1) }
    if base.any? { focus_tag?(_1) }
      base.select { focus_tag?(_1) }
    else
      base
    end
  end

  # True when at least one non-skipped test has :focus and at least one runnable test does not
  # (subset of the suite is selected).
  def self.focus_filter_active?(candidates)
    return false if candidates.empty?

    candidates.any? { focus_tag?(_1) } && candidates.any? { !focus_tag?(_1) }
  end

  def self.push_group(title, tags: [])
    entry = { title: title.to_s, tags: Array(tags).map(&:to_sym) }
    (Thread.current[:verity_group_stack] ||= []) << entry
  end

  def self.pop_group
    Thread.current[:verity_group_stack]&.pop
  end

  # Snapshot of nested `group` titles for the current thread.
  def self.group_path_for_registration
    stack = Thread.current[:verity_group_stack]
    return [].freeze if stack.nil? || stack.empty?

    stack.map { _1[:title] }.freeze
  end

  def self.inherited_group_tags_for_registration
    stack = Thread.current[:verity_group_stack]
    return [].freeze if stack.nil? || stack.empty?

    stack.flat_map { |g| g[:tags] }.freeze
  end

  def self.clear_group_stack!
    Thread.current[:verity_group_stack] = []
  end

  # Resolve a reporter from a CLI or config string.
  #
  # Built-in names (case-insensitive): +documentation+ (+doc+), +colored+ (+colored_dots+), +dots+, +null+ (+none+, +silent+).
  # Custom: +"./path/to/reporter.rb:ClassName"+ or +"./path/to/reporter.rb:Mod::Klass"+ — uses Kernel#load then +.new+.
  #
  # Built-ins that write output use +$stdout+. The configuration default is {Reporters::ColoredDotsReporter}.
  #
  # @param spec [String]
  # @return [Object] instance suitable for {Configuration#reporter}
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

  module Registry
    @tests = []

    def self.register(test) = @tests << test
    def self.all = @tests.dup
    def self.clear = @tests.clear
    def self.find(fingerprint) = @tests.find { |t| t.fingerprint == fingerprint }
  end

  module DSL
    include Assertions

    def group(title, tags: [], &block)
      raise ArgumentError, "`group` requires a block" unless block

      Verity.push_group(title, tags: tags)
      yield
    ensure
      Verity.pop_group
    end

    def test(description, tags: [], timeout: nil, requires: [], **resources, &fn)
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
          inherited_group_tags: Verity.inherited_group_tags_for_registration
        )
      )
    end
  end

  def self.before_worker_start(&block) = hooks[:before_worker_start] << block
  def self.before_test(&block) = hooks[:before_test] << block
  def self.after_test(&block) = hooks[:after_test] << block

  def self.register_resource(name, conflicts_with:)
    resource_resolvers[name] = conflicts_with
  end

  def self.hooks
    @hooks ||= { before_worker_start: [], before_test: [], after_test: [] }
  end

  def self.resource_resolvers
    @resource_resolvers ||= {}
  end

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
        counts = manifest.count_by_status
        problem_rows = manifest.failures_for_report
        configuration.reporter.on_parallel_complete(counts: counts, problem_rows: problem_rows)
      ensure
        manifest.close
      end

      ok
    else
      manifest = Manifest.open(path)
      begin
        manifest.migrate!
        manifest.replace_tests(runnable_tests)
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
      manifest.replace_tests(runnable_tests)
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
