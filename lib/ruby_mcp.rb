# frozen_string_literal: true

require "faraday"
require "jwt"
require "json"
require "json-schema"
require "concurrent"
require "logger"

require_relative "ruby_mcp/version"
require_relative "ruby_mcp/errors"
require_relative "ruby_mcp/configuration"

require_relative "ruby_mcp/models/context"
require_relative "ruby_mcp/models/message"
require_relative "ruby_mcp/models/engine"
require_relative "ruby_mcp/providers/base"
require_relative "ruby_mcp/storage/base"
require_relative "ruby_mcp/storage/memory"
require_relative "ruby_mcp/server/router"
require_relative "ruby_mcp/server/base_controller"
require_relative "ruby_mcp/server/app"
require_relative "ruby_mcp/server/controller"
require_relative "ruby_mcp/server/engines_controller"
require_relative "ruby_mcp/server/contexts_controller"
require_relative "ruby_mcp/server/messages_controller"
require_relative "ruby_mcp/server/content_controller"
require_relative "ruby_mcp/server/generate_controller"
require_relative "ruby_mcp/providers/openai"
require_relative "ruby_mcp/providers/anthropic"
require_relative "ruby_mcp/validator"

module RubyMCP
  class << self
    attr_accessor :configuration
    attr_writer :logger

    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
    end

    def logger
      @logger ||= Logger.new($stdout).tap do |log|
        log.progname = self.name
      end
    end
  end
end