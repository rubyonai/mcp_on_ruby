# frozen_string_literal: true

require 'logger'

module MCP
  # Configuration options for MCP
  class Configuration
    # Server options
    attr_accessor :server_port, :server_host
    attr_accessor :server_transport
    
    # Client options
    attr_accessor :client_transport, :client_url
    
    # Authentication options
    attr_accessor :auth_enabled, :auth_method, :auth_options
    
    # Common options
    attr_accessor :log_level
    attr_accessor :default_timeout
    
    # Initialize with default values
    def initialize
      # Server defaults
      @server_port = 3000
      @server_host = '0.0.0.0'
      @server_transport = :http
      
      # Client defaults
      @client_transport = :http
      @client_url = 'http://localhost:3000/mcp'
      
      # Authentication defaults
      @auth_enabled = false
      @auth_method = :none
      @auth_options = {}
      
      # Common defaults
      @log_level = Logger::INFO
      @default_timeout = 30 # seconds
    end
    
    # Get the transport options for server
    # @return [Hash] The transport options
    def server_transport_options
      {
        transport: @server_transport,
        port: @server_port,
        host: @server_host,
        log_level: @log_level
      }
    end
    
    # Get the transport options for client
    # @return [Hash] The transport options
    def client_transport_options
      {
        transport: @client_transport,
        url: @client_url,
        log_level: @log_level,
        timeout: @default_timeout
      }
    end
    
    # Configure OAuth authentication
    # @param options [Hash] OAuth options
    def configure_oauth(options)
      @auth_enabled = true
      @auth_method = :oauth
      @auth_options = options
    end
  end
end