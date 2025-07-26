# frozen_string_literal: true

require 'logger'
require 'json'
require 'json-schema'
require 'rack'
require 'webrick'

require_relative 'mcp_on_ruby/version'
require_relative 'mcp_on_ruby/errors'
require_relative 'mcp_on_ruby/configuration'
require_relative 'mcp_on_ruby/server'
require_relative 'mcp_on_ruby/tool'
require_relative 'mcp_on_ruby/resource'
require_relative 'mcp_on_ruby/transport'

# Rails integration if available
if defined?(Rails)
  require_relative 'mcp_on_ruby/railtie'
end

# Production-ready Model Context Protocol implementation for Rails
module McpOnRuby
  class << self
    attr_writer :logger
    attr_accessor :configuration

    # Configure the library
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
        log.progname = 'McpOnRuby'
        log.level = configuration&.log_level || Logger::INFO
      end
    end

    # Create a new MCP server
    # @param options [Hash] Server configuration options
    # @yield [Server] The server instance for configuration
    # @return [Server] The configured server
    def server(options = {}, &block)
      Server.new(options, &block)
    end

    # Create a tool with DSL
    # @param name [String] Tool name
    # @param description [String] Tool description
    # @param input_schema [Hash] JSON Schema for validation
    # @param options [Hash] Additional options (metadata, tags)
    # @param block [Proc] Tool implementation
    # @return [Tool] The created tool
    def tool(name, description = '', input_schema = {}, **options, &block)
      raise ArgumentError, 'Tool implementation block is required' unless block_given?

      Class.new(Tool) do
        define_method :execute do |arguments, context|
          case block.arity
          when 0
            instance_exec(&block)
          when 1
            instance_exec(arguments, &block)
          else
            instance_exec(arguments, context, &block)
          end
        end
      end.new(
        name: name,
        description: description,
        input_schema: input_schema,
        metadata: options[:metadata] || {},
        tags: options[:tags] || []
      )
    end

    # Create a resource with DSL
    # @param uri [String] Resource URI
    # @param options [Hash] Resource options (name, description, etc.)
    # @param block [Proc] Resource implementation
    # @return [Resource] The created resource
    def resource(uri, **options, &block)
      raise ArgumentError, 'Resource implementation block is required' unless block_given?

      Class.new(Resource) do
        define_method :fetch_content do |params, context|
          case block.arity
          when 0
            instance_exec(&block)
          when 1
            instance_exec(params, &block)
          else
            instance_exec(params, context, &block)
          end
        end
      end.new(
        uri: uri,
        name: options[:name],
        description: options[:description] || '',
        mime_type: options[:mime_type] || 'application/json',
        metadata: options[:metadata] || {},
        tags: options[:tags] || []
      )
    end

    # Broadcast resource update to connected SSE clients
    # @param uri [String] Resource URI that was updated
    # @param event_type [String] Type of event
    def broadcast_resource_update(uri, event_type = 'resource_updated')
      # This would be implemented when SSE is fully integrated
      logger.info("Resource update broadcasted: #{uri} (#{event_type})")
    end

    # Mount MCP server in Rails application
    # @param app [Rails::Application] The Rails application
    # @param options [Hash] Mounting options
    # @yield [Server] The server instance for configuration
    # @return [Server] The mounted server
    def mount_in_rails(app, **options, &block)
      server = self.server(options, &block)
      
      # Mount the transport middleware
      app.config.middleware.use(
        Transport::RackMiddleware,
        server: server,
        **options
      )
      
      server
    end
  end
end

# Alias for convenience
MCP = McpOnRuby