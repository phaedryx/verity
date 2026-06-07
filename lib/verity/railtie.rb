# frozen_string_literal: true

require "rails/railtie"
require "verity"
require "verity/rails"

module Verity
  # Public: Rails integration — loads rake tasks when the verity gem is in the
  # host app's Gemfile (auto-required by Bundler in Rails apps).
  class Railtie < ::Rails::Railtie
    rake_tasks do
      load File.expand_path("tasks/verity.rake", __dir__)
    end
  end
end
