# frozen_string_literal: true

require_relative 'server/tools/tool'
require_relative 'server/tools/manager'
require_relative 'server/resources/resource'
require_relative 'server/resources/manager'
require_relative 'server/prompts/prompt'
require_relative 'server/prompts/manager'
require_relative 'server/roots/root'
require_relative 'server/roots/manager'
require_relative 'server/dsl'
require_relative 'server/server'

module MCP
  # Creates a new server instance with optional block configuration
  # @param options [Hash] Server options
  # @yield [Server::Server] The server instance
  # @return [Server::Server] The server instance
  def self.Server(options = {})
    server = Server::Server.new(options)
    yield server if block_given?
    server
  end
  
  # Main server class for MCP
  class Server
    # Create a new server instance
    # @param options [Hash] Server options
    # @yield [self] The server instance
    # @return [self] The server instance
    def initialize(options = {})
      @server = MCP.Server(options)
      
      # Include server DSL
      extend MCP::Server::DSL
      
      yield self if block_given?
      
      self
    end
    
    # Start the server
    def start
      @server.start
    end
    
    # Stop the server
    def stop
      @server.stop
    end
    
    # Check if the server is running
    # @return [Boolean] true if the server is running
    def running?
      @server.running?
    end
    
    # Forward other methods to the server instance
    def method_missing(method, *args, &block)
      if @server.respond_to?(method)
        @server.send(method, *args, &block)
      else
        super
      end
    end
    
    # Respond to check for forwarded methods
    def respond_to_missing?(method, include_private = false)
      @server.respond_to?(method, include_private) || super
    end
  end
end