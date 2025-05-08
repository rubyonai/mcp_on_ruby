# frozen_string_literal: true

require 'logger'
require 'json'
require 'securerandom'

require_relative 'ruby_mcp/version'
require_relative 'ruby_mcp/errors'
require_relative 'ruby_mcp/protocol'
require_relative 'ruby_mcp/client'
require_relative 'ruby_mcp/server'

# The Model Context Protocol (MCP) implementation
module MCP
  class << self
    attr_accessor :configuration
    attr_writer :logger

    # Configure the MCP library
    # @yield [Configuration] The configuration object
    # @return [Configuration] The configuration object
    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
      configuration
    end

    # Get the logger
    # @return [Logger] The logger
    def logger
      @logger ||= Logger.new($stdout).tap do |log|
        log.progname = name
        log.level = configuration&.log_level || Logger::INFO
      end
    end
  end
end

# Load configuration
require_relative 'ruby_mcp/configuration'

# Load module aliases to ensure consistent module access patterns
require_relative 'ruby_mcp/module_aliases'