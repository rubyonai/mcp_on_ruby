# frozen_string_literal: true

require 'securerandom'

module MCP
  module Server
    # Main server class for MCP
    class Server
      attr_reader :id, :name, :transport, :options, :logger

      def initialize(options = {})
        @id = SecureRandom.uuid
        @name = options[:name] || 'MCP Ruby Server'
        @options = options
        @logger = options[:logger] || MCP.logger
        @transport = initialize_transport(options)
        @event_handlers = {}
        @method_handlers = {}
        @auth_provider = nil
        @permissions = nil
        @running = false
        
        # Set up the default method handlers
        setup_default_handlers
      end

      # Start the server
      def start
        return if @running
        
        @running = true
        @logger.info("Starting MCP server '#{@name}' (#{@id})")
        
        # Start the transport
        @transport.connect
        
        # Start handling messages
        handle_messages
      end

      # Stop the server
      def stop
        return unless @running
        
        @running = false
        @logger.info("Stopping MCP server '#{@name}' (#{@id})")
        
        # Stop the transport
        @transport.disconnect
      end

      # Check if the server is running
      # @return [Boolean] true if the server is running
      def running?
        @running
      end

      # Register a handler for a specific method
      # @param method [String] The method to handle
      # @param &block [Proc] The handler block
      def on_method(method, &block)
        @method_handlers[method] = block
      end

      # Register a handler for a specific event
      # @param event [Symbol] The event to handle
      # @param &block [Proc] The handler block
      def on_event(event, &block)
        @event_handlers[event] = block
      end
      
      # Set the authentication provider
      # @param provider [MCP::Server::Auth::OAuth] The authentication provider
      # @param permissions [MCP::Server::Auth::Permissions] The permissions manager
      def set_auth_provider(provider, permissions)
        @auth_provider = provider
        @permissions = permissions
        
        # Update the transport if it's already initialized
        if @transport && @transport.respond_to?(:set_auth_middleware)
          @transport.set_auth_middleware(@auth_provider, @permissions)
        end
      end

      private

      # Initialize the transport
      # @param options [Hash] The transport options
      # @return [Transport::Base] The transport instance
      def initialize_transport(options)
        transport_options = options[:transport_options] || MCP.configuration.server_transport_options
        
        # Ensure we're using server mode
        transport_options[:mode] = :server
        
        # Set message handler
        transport_options[:message_handler] = method(:handle_rpc_message)
        
        # Add auth provider and permissions if available
        if @auth_provider && @permissions
          transport_options[:auth_provider] = @auth_provider
          transport_options[:permissions] = @permissions
        end
        
        MCP::Protocol.create_server(transport_options)
      end

      # Set up the default method handlers
      def setup_default_handlers
        # Initialize request handler
        on_method('initialize') do |params|
          handle_initialize(params)
        end
        
        # Ping request handler
        on_method('ping') do |_params|
          { pong: true }
        end
      end

      # Handle initialization request
      # @param params [Hash] The initialization parameters
      # @return [Hash] The initialization result
      def handle_initialize(params)
        protocol_version = params[:protocolVersion]
        client_info = params[:clientInfo]
        
        @logger.info("Client initialization: #{client_info[:name]} #{client_info[:version]} (Protocol: #{protocol_version})")
        
        # Check protocol version
        if protocol_version != MCP::PROTOCOL_VERSION
          @logger.warn("Protocol version mismatch: client=#{protocol_version}, server=#{MCP::PROTOCOL_VERSION}")
        end
        
        # Return initialization result
        {
          serverInfo: {
            name: @name,
            version: MCP::VERSION
          },
          protocolVersion: MCP::PROTOCOL_VERSION,
          capabilities: server_capabilities
        }
      end

      # Get the server capabilities
      # @return [Hash] The server capabilities
      def server_capabilities
        {
          # Set default capabilities here
          # Will be extended by individual capability providers
        }
      end

      # Handle incoming messages
      def handle_messages
        # For server mode with HTTP, the transport handles incoming messages
        # and calls the message handler
      end
      
      # Handle an RPC message
      # @param message [Hash] The JSON-RPC message
      # @return [Hash, nil] The result or nil
      def handle_rpc_message(message)
        return nil unless message.is_a?(Hash)
        
        method_name = message[:method]
        params = message[:params]
        id = message[:id]
        
        @logger.debug("Handling method: #{method_name}")
        
        # Find the method handler
        handler = @method_handlers[method_name]
        
        if handler
          begin
            # Call the handler
            result = handler.call(params)
            
            # Return the result for requests (messages with an ID)
            if id
              result
            else
              # For notifications, return nil
              nil
            end
          rescue => e
            @logger.error("Error handling method #{method_name}: #{e.message}")
            @logger.error(e.backtrace.join("\n"))
            
            # Return error for requests
            if id
              {
                code: -32603,
                message: "Internal error: #{e.message}"
              }
            else
              # For notifications, return nil
              nil
            end
          end
        else
          @logger.warn("Unknown method: #{method_name}")
          
          # Return method not found error for requests
          if id
            {
              code: -32601,
              message: "Method not found: #{method_name}"
            }
          else
            # For notifications, return nil
            nil
          end
        end
      end
    end
  end
end