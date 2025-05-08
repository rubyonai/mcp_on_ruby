# frozen_string_literal: true

require_relative 'server/tools/tool'
require_relative 'server/tools/manager'
require_relative 'server/resources/resource'
require_relative 'server/resources/manager'
require_relative 'server/prompts/prompt'
require_relative 'server/prompts/manager'
require_relative 'server/roots/root'
require_relative 'server/roots/manager'
require_relative 'server/auth'
require_relative 'server/dsl'
require_relative 'server/server'

module MCP
  # Module for MCP server implementation
  module Server
    # Module functions for server creation
  end

  # Creates a new server instance with optional block configuration
  # @param options [Hash] Server options
  # @yield [Server::Server] The server instance
  # @return [Server::Server] The server instance
  def self.Server(options = {})
    server = Server::Server.new(options)
    
    # Set up authentication if enabled
    if options[:auth_enabled] || MCP.configuration.auth_enabled
      auth_options = options[:auth_options] || MCP.configuration.auth_options
      
      case options[:auth_method] || MCP.configuration.auth_method
      when :oauth
        auth_provider = Server::Auth.create_oauth_provider(auth_options)
        permissions = Server::Auth.create_permissions_manager(auth_provider)
        server.set_auth_provider(auth_provider, permissions)
      end
    end
    
    yield server if block_given?
    server
  end
  
  # Create a new server instance
  # @param options [Hash] The server options
  # @return [ServerWrapper] A server instance
  def self.server(options = {})
    ServerWrapper.new(options)
  end

  # Wrapper class that delegates to the underlying server
  # This avoids the naming conflict with MCP::Server module
  class ServerWrapper
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
    
    # Set the authentication provider
    # @param provider [MCP::Server::Auth::OAuth] The authentication provider
    # @param permissions [MCP::Server::Auth::Permissions] The permissions manager
    def set_auth_provider(provider, permissions)
      @server.set_auth_provider(provider, permissions)
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