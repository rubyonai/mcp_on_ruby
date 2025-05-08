# frozen_string_literal: true

require 'securerandom'

module MCP
  module Client
    # Main client class for MCP
    class Client
      attr_reader :id, :name, :options, :logger, :transport, :connection
      
      def initialize(options = {})
        @id = SecureRandom.uuid
        @name = options[:name] || 'MCP Ruby Client'
        @options = options
        @logger = options[:logger] || MCP.logger
        @transport = initialize_transport(options)
        @connection = nil
        @event_handlers = {}
        @connected = false
      end
      
      # Connect to the MCP server
      # @return [self] The client instance
      def connect
        return self if @connected
        
        @logger.info("Connecting to MCP server as '#{@name}' (#{@id})")
        
        # Initialize the transport
        transport_connection = @transport.connect
        
        # Create the connection manager
        @connection = MCP::Protocol::Connection.new(transport_connection)
        
        # Initialize the connection with the server
        initialize_connection
        
        @connected = true
        self
      end
      
      # Disconnect from the MCP server
      # @return [self] The client instance
      def disconnect
        return self unless @connected
        
        @logger.info("Disconnecting from MCP server")
        
        # Disconnect the transport
        @transport.disconnect
        
        @connected = false
        @connection = nil
        
        self
      end
      
      # Check if the client is connected
      # @return [Boolean] true if the client is connected
      def connected?
        @connected && @transport.connected?
      end
      
      # List available tools on the server
      # @return [Array<Hash>] The list of available tools
      def list_tools
        ensure_connected
        
        request = MCP::Protocol::JsonRPC.request('tools/list')
        response = @connection.send_request(request)
        
        if response[:error]
          raise MCP::Errors::ClientError, "Error listing tools: #{response[:error][:message]}"
        end
        
        response[:result][:tools]
      end
      
      # Call a tool on the server
      # @param name [String] The name of the tool to call
      # @param arguments [Hash] The arguments to pass to the tool
      # @return [Array<Hash>] The tool result content
      def call_tool(name, arguments = {})
        ensure_connected
        
        request = MCP::Protocol::JsonRPC.request('tools/call', {
          name: name,
          arguments: arguments
        })
        
        response = @connection.send_request(request)
        
        if response[:error]
          raise MCP::Errors::ClientError, "Error calling tool: #{response[:error][:message]}"
        end
        
        result = response[:result]
        
        if result[:isError]
          error_message = get_error_message(result[:content])
          raise MCP::Errors::ToolError, "Tool error: #{error_message}"
        end
        
        result[:content]
      end
      
      # Register a handler for a specific event
      # @param event [Symbol] The event to handle
      # @param &block [Proc] The handler block
      def on_event(event, &block)
        @event_handlers[event] = block
      end
      
      private
      
      # Initialize the transport
      # @param options [Hash] The transport options
      # @return [MCP::Protocol::Transport::Base] The transport instance
      def initialize_transport(options)
        transport_options = options[:transport_options] || MCP.configuration.client_transport_options
        MCP::Protocol.create_transport(transport_options)
      end
      
      # Initialize the connection with the server
      def initialize_connection
        @connection.initialize_connection(
          client_info: {
            name: @name,
            version: MCP::VERSION
          },
          protocol_version: MCP::PROTOCOL_VERSION,
          capabilities: client_capabilities
        )
      end
      
      # Get the client capabilities
      # @return [Hash] The client capabilities
      def client_capabilities
        {
          # Set default capabilities here
        }
      end
      
      # Get error message from content
      # @param content [Array<Hash>] The content array
      # @return [String] The error message
      def get_error_message(content)
        return "Unknown error" if content.nil? || content.empty?
        
        text_content = content.find { |c| c[:type] == 'text' }
        text_content ? text_content[:text] : "Unknown error"
      end
      
      # Ensure the client is connected
      # @raise [MCP::Errors::ConnectionError] If the client is not connected
      def ensure_connected
        unless connected?
          raise MCP::Errors::ConnectionError, "Client is not connected"
        end
      end
    end
  end
end