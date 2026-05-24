# frozen_string_literal: true

require "benchmark"

N = 10
DEVNULL = "/dev/null"

suites = {
  "Minitest" => "ruby test/assertions_test.rb",
  "RSpec"    => "rspec spec/assertions_spec.rb",
  "Verity"   => "ruby verity/assertions_verity_test.rb"
}

puts "Benchmarking each suite (#{N} runs, output suppressed)\n\n"

Benchmark.bmbm(10) do |x|
  suites.each do |name, cmd|
    x.report(name) { N.times { system("#{cmd} > #{DEVNULL} 2>&1") } }
  end
end

puts "\nPer-run averages:"
suites.each do |name, cmd|
  elapsed = Benchmark.measure { N.times { system("#{cmd} > #{DEVNULL} 2>&1") } }.real
  puts "  #{name.ljust(10)} #{"%.3f" % (elapsed / N)}s"
end
