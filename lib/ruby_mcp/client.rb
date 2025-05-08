# frozen_string_literal: true

require_relative 'client/client'
require_relative 'client/retry'
require_relative 'client/streaming'

module MCP
  # Creates a new client instance with optional block configuration
  # @param options [Hash] Client options
  # @yield [Client::Client] The client instance
  # @return [Client::Client] The client instance
  def self.Client(options = {})
    client = Client::Client.new(options)
    
    # Add additional capabilities
    client.extend(Client::Retry)
    client.extend(Client::Streaming)
    
    yield client if block_given?
    client
  end
  
  # Main client class for MCP
  class Client
    # Create a new client instance
    # @param options [Hash] Client options
    # @yield [self] The client instance
    # @return [self] The client instance
    def initialize(options = {})
      @client = MCP.Client(options)
      
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
    
    # Get the list of available tools
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