# frozen_string_literal: true

require_relative 'client/client'
require_relative 'client/retry'
require_relative 'client/streaming'
require_relative 'client/sampling'
require_relative 'client/roots'
require_relative 'client/auth'

module MCP
  # Module for MCP client implementation
  module Client
    # Module functions for client creation
  end

  # Creates a new client instance with optional block configuration
  # @param options [Hash] Client options
  # @yield [Client::Client] The client instance
  # @return [Client::Client] The client instance
  def self.Client(options = {})
    client = Client::Client.new(options)
    
    # Add additional capabilities
    client.extend(Client::Retry)
    client.extend(Client::Streaming)
    client.extend(Client::Sampling)
    client.extend(Client::Roots)
    client.extend(Client::Auth)
    
    # Configure OAuth if options are provided
    if options[:oauth]
      client.set_oauth_credentials(options[:oauth])
    end
    
    # Set access token if provided
    if options[:access_token]
      client.set_access_token(options[:access_token])
    end
    
    yield client if block_given?
    client
  end
  
  # Create a new client instance
  # @param options [Hash] The client options
  # @return [ClientWrapper] A client instance
  def self.client(options = {})
    ClientWrapper.new(options)
  end

  # Wrapper class that delegates to the underlying client
  # This avoids the naming conflict with MCP::Client module
  class ClientWrapper
    # Create a new client instance
    # @param options [Hash] Client options
    # @yield [self] The client instance
    # @return [self] The client instance
    def initialize(options = {})
      @client = MCP.Client(options)
      
      # Set up roots and sampling handlers if provided
      @client.set_roots(options[:roots]) if options[:roots]
      @client.set_sampling_handler(options[:sampling_handler]) if options[:sampling_handler]
      
      yield self if block_given?
      
      self
    end
    
    # Connect to the MCP server
    # @return [self] The client instance
    def connect
      @client.connect
      self
    end
    
    # Disconnect from the MCP server
    # @return [self] The client instance
    def disconnect
      @client.disconnect
      self
    end
    
    # Check if the client is connected
    # @return [Boolean] true if the client is connected
    def connected?
      @client.connected?
    end
    
    # List available tools on the server
    # @return [Array<Hash>] The list of available tools
    def list_tools
      @client.list_tools
    end
    
    # Call a tool on the server
    # @param name [String] The name of the tool to call
    # @param arguments [Hash] The arguments to pass to the tool
    # @return [Array<Hash>] The tool result content
    def call_tool(name, arguments = {})
      @client.call_tool(name, arguments)
    end
    
    # Stream a tool call on the server
    # @param name [String] The name of the tool to call
    # @param arguments [Hash] The arguments to pass to the tool
    # @yield [Hash] Each content chunk as it arrives
    # @return [Array<Hash>] The complete content when done
    def stream_tool(name, arguments = {}, &block)
      @client.stream_tool(name, arguments, &block)
    end
    
    # Execute a block with retry
    # @param options [Hash] The retry options
    # @param retriable_errors [Array<Class>] The errors to retry on
    # @param retry_condition [Proc] Optional condition for retry
    # @yield The block to execute
    # @return [Object] The result of the block
    def with_retry(options = {}, retriable_errors = [StandardError], retry_condition = nil, &block)
      @client.with_retry(options, retriable_errors, retry_condition, &block)
    end
    
    # List available resources on the server
    # @return [Array<Hash>] The list of available resources
    def list_resources
      @client.list_resources
    end
    
    # List available resource templates on the server
    # @return [Array<Hash>] The list of available resource templates
    def list_resource_templates
      @client.list_resource_templates
    end
    
    # Read a resource from the server
    # @param uri [String] The URI of the resource to read
    # @param params [Hash] Optional parameters for template resources
    # @return [Array<Hash>] The resource content
    def read_resource(uri, params = nil)
      @client.read_resource(uri, params)
    end
    
    # List available prompts on the server
    # @return [Array<Hash>] The list of available prompts
    def list_prompts
      @client.list_prompts
    end
    
    # Get a prompt from the server
    # @param name [String] The name of the prompt to get
    # @param arguments [Hash] Optional arguments for the prompt
    # @return [Array<Hash>] The prompt messages
    def get_prompt(name, arguments = {})
      @client.get_prompt(name, arguments)
    end
    
    # List available roots on the server
    # @return [Array<Hash>] The list of available roots
    def list_roots
      @client.list_roots
    end
    
    # Read a file from a root on the server
    # @param root [String] The name of the root to read from
    # @param path [String] The path to read
    # @return [String] The file content
    def read_root_file(root, path)
      @client.read_root_file(root, path)
    end
    
    # Allow models to call their host model for text generation
    # @param prompt [String, Array<Hash>] The prompt to generate from
    # @param options [Hash] Generation options
    # @return [String] The generated text
    def sample(prompt, options = {})
      @client.sample(prompt, options)
    end
    
    # Set the roots list handler
    # @param roots [Array<Hash>] The roots to register
    def set_roots(roots)
      @client.set_roots(roots)
    end
    
    # Set the sampling handler
    # @param handler [Proc] The handler function
    def set_sampling_handler(handler)
      @client.set_sampling_handler(handler)
    end
    
    # Set OAuth credentials
    # @param options [Hash] OAuth options
    def set_oauth_credentials(options)
      @client.set_oauth_credentials(options)
    end
    
    # Get an authorization URL
    # @param state [String] State parameter for CSRF protection
    # @param redirect_uri [String] The redirect URI
    # @param scopes [Array<String>] The requested scopes
    # @return [String] The authorization URL
    def authorization_url(state, redirect_uri = nil, scopes = nil)
      @client.authorization_url(state, redirect_uri, scopes)
    end
    
    # Exchange an authorization code for a token
    # @param code [String] The authorization code
    # @param redirect_uri [String] The redirect URI
    # @return [OAuth2::AccessToken] The access token
    def exchange_code(code, redirect_uri = nil)
      @client.exchange_code(code, redirect_uri)
    end
    
    # Refresh the access token
    # @return [OAuth2::AccessToken] The refreshed access token
    def refresh_token
      @client.refresh_token
    end
    
    # Set an access token directly
    # @param token [String, OAuth2::AccessToken] The access token
    def set_access_token(token)
      @client.set_access_token(token)
    end
    
    # Forward other methods to the client instance
    def method_missing(method, *args, &block)
      if @client.respond_to?(method)
        @client.send(method, *args, &block)
      else
        super
      end
    end
    
    # Respond to check for forwarded methods
    def respond_to_missing?(method, include_private = false)
      @client.respond_to?(method, include_private) || super
    end
  end
end