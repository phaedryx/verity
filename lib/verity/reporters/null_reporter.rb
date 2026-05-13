# frozen_string_literal: true

module Verity
  module Reporters
    # Public: Silent reporter that discards all output. Used in forked worker
    # processes and in tests where reporter output is unwanted.
    class NullReporter
      include Verity::Reporter
    end
  end
end
