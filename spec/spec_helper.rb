# frozen_string_literal: true

require "ruby_mcp"
require "webmock/rspec"
require 'simplecov'
require 'codecov'

SimpleCov.start do
  add_filter '/spec/'
  add_filter '/vendor/'
  track_files 'lib/**/*.rb'  # Explicitly tell it which files to track
  enable_coverage :branch    # Enable branch coverage too
end

# Use this formatter setup
SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::Codecov
])

# Configure WebMock to allow localhost connections for testing
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end