# frozen_string_literal: true

require 'securerandom'
require_relative 'json_rpc'

module MCP
  module Protocol
    # Manages a connection to an MCP endpoint
    class Connection
      attr_reader :transport, :id

      def initialize(transport)
        @transport = transport
        @id = SecureRandom.uuid
        @pending_requests = {}
        @message_handlers = {}
        @initialized = false
      end

      # Initialize the connection with the MCP server
      # @param options [Hash] The initialization options
      # @return [Boolean] True if initialization was successful
      def initialize_connection(options = {})
        return true if @initialized
        
        client_info = options[:client_info] || {
          name: 'MCP Ruby Client',
          version: MCP::VERSION
        }
        
        protocol_version = options[:protocol_version] || MCP::PROTOCOL_VERSION
        
        request = JsonRPC.request('initialize', {
          protocolVersion: protocol_version,
          clientInfo: client_info,
          capabilities: options[:capabilities] || {}
        })
        
        response = send_request(request)
        
        if response[:error]
          raise "Initialization failed: #{response[:error][:message]}"
        end
        
        @initialized = true
      end

      # Send a request and wait for the response
      # @param request [Hash] The request message
      # @return [Hash] The response message
      def send_request(request)
        @transport.send_message(request)
        
        # TODO: Implement waiting for response
        # For now, we'll just return a dummy response
        JsonRPC.success(request[:id], {})
      end

      # Send a notification
      # @param notification [Hash] The notification message
      def send_notification(notification)
        @transport.send_message(notification)
      end

      # Register a handler for a specific method
      # @param method [String] The method to handle
      # @param &block [Proc] The handler block
      def on_method(method, &block)
        @message_handlers[method] = block
      end

      # Start handling messages
      # @yield [Hash] The received message
      def start
        @transport.stream_messages do |message|
          handle_message(message)
        end
      end

      # Stop handling messages
      def stop
        @transport.disconnect
      end

      private

      # Handle an incoming message
      # @param message [Hash] The received message
      def handle_message(message)
        # Handle response
        if message[:id] && (message[:result] || message[:error])
          handle_response(message)
        # Handle request
        elsif message[:method] && message[:id]
          handle_request(message)
        # Handle notification
        elsif message[:method]
          handle_notification(message)
        end
      end

      # Handle a response message
      # @param response [Hash] The response message
      def handle_response(response)
        request = @pending_requests.delete(response[:id])
        request[:promise].fulfill(response) if request
      end

      # Handle a request message
      # @param request [Hash] The request message
      def handle_request(request)
        handler = @message_handlers[request[:method]]
        
        if handler
          begin
            result = handler.call(request[:params])
            response = JsonRPC.success(request[:id], result)
          rescue => e
            response = JsonRPC.error(request[:id], JsonRPC::ErrorCode::INTERNAL_ERROR, e.message)
          end
          
          @transport.send_message(response)
        else
          response = JsonRPC.error(request[:id], JsonRPC::ErrorCode::METHOD_NOT_FOUND, "Method not found: #{request[:method]}")
          @transport.send_message(response)
        end
      end

      # Handle a notification message
      # @param notification [Hash] The notification message
      def handle_notification(notification)
        handler = @message_handlers[notification[:method]]
        handler&.call(notification[:params])
      end
    end
  end
end