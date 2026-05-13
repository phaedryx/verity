# frozen_string_literal: true

require "digest"
require "pathname"
require "prism"

module Verity
  module Fingerprint
    HEX_LENGTH = 16

    class << self
      THREAD_KEY = :__verity_fp_plan__

      def install_plan!(absolute_path)
        Thread.current[THREAD_KEY] = plan_file(absolute_path)
      end

      def clear_plan!
        Thread.current[THREAD_KEY] = nil
      end

      def lookup(line)
        Thread.current[THREAD_KEY]&.[](line)
      end

      def fallback_fingerprint(file, line)
        rel = relative_source_path(file)
        sha = Digest::SHA1.hexdigest("#{file}:#{line}")[0, HEX_LENGTH]
        "#{rel}:#{sha}"
      end

      def plan_file(absolute_path)
        source = File.read(absolute_path, encoding: "UTF-8")
        result = Prism.parse(source, filepath: File.expand_path(absolute_path))
        return {} unless result.success?

        program = result.value
        rows = []
        each_load_time_test(program) do |call|
          body = call.block.body
          canon = canonical(body)
          body_hex = Digest::SHA1.hexdigest(canon)[0, HEX_LENGTH]
          rows << { line: call.location.start_line, body_hex: body_hex }
        end

        relative = relative_source_path(absolute_path)
        by_hex = rows.group_by { _1[:body_hex] }
        plan = {}
        rows.each do |row|
          line = row[:line]
          body_hex = row[:body_hex]
          plan[line] =
            if by_hex[body_hex].length > 1
              "#{relative}:#{body_hex}:#{line}"
            else
              "#{relative}:#{body_hex}"
            end
        end
        plan
      end

      def derive_method_suffix(fingerprint)
        parts = fingerprint.split(":")
        hex =
          if parts.size >= 3 && parts.last.match?(/\A\d+\z/)
            parts[-2]
          else
            parts[-1]
          end
        raise ArgumentError, "invalid fingerprint (expected ...:#{HEX_LENGTH} hex chars): #{fingerprint}" unless /\A[a-f0-9]{#{HEX_LENGTH}}\z/.match?(hex)

        hex
      end

      private

      def relative_source_path(absolute_path)
        abs = File.expand_path(absolute_path)
        Pathname(abs).relative_path_from(Pathname(Dir.pwd)).to_s
      rescue ArgumentError
        File.basename(abs)
      end

      def each_load_time_test(node, inside_block = false, &block)
        return unless node.is_a?(Prism::Node)

        if node.is_a?(Prism::CallNode) && !inside_block && verity_test_call?(node)
          block.call(node)
        end

        node.compact_child_nodes.each do |child|
          deeper = inside_block
          deeper = true if node.is_a?(Prism::CallNode) && child.is_a?(Prism::BlockNode)
          each_load_time_test(child, deeper, &block)
        end
      end

      def verity_test_call?(node)
        node.is_a?(Prism::CallNode) && node.name == :test && node.receiver.nil? && node.block
      end

      def canonical(node)
        return "" if node.nil?

        if node.is_a?(Prism::StatementsNode)
          return node.body.map { canonical(_1) }.join(";")
        end

        if node.is_a?(Prism::Node)
          label = node.class.name.split("::").last
          inner = node.compact_child_nodes.map { canonical(_1) }.join(" ")
          return "(#{label} #{inner})"
        end

        raise ArgumentError, "unexpected node: #{node.class}"
      end
    end
  end
end
