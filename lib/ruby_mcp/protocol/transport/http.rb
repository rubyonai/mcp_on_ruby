# frozen_string_literal: true

require 'uri'
require 'net/http'
require 'json'
require 'securerandom'
require 'faye/websocket'
require 'eventmachine'
require 'rack'

module MCP
  module Protocol
    module Transport
      # HTTP transport for MCP using the streamable HTTP protocol
      class HTTP < Base
        attr_reader :url, :headers, :connection

        def initialize(options = {})
          super
          @url = options[:url] || 'http://localhost:3000/mcp'
          @headers = options[:headers] || {}
          @connection = nil
          @request_queue = Queue.new
          @response_handlers = {}
          @event_handlers = {}
          @connection_id = nil
          
          # Authentication components
          @auth_provider = options[:auth_provider]
          @permissions = options[:permissions]
          @auth_token = options[:auth_token]
          
          # Add auth token to headers if provided
          add_auth_header if @auth_token
        end

        # Connect to the MCP endpoint
        # @return [Connection] An established connection
        def connect
          @connection_id = SecureRandom.uuid
          
          # Start EventMachine in a separate thread if not running
          unless EventMachine.reactor_running?
            Thread.new do
              EventMachine.run
            end
            # Wait for EventMachine to start
            sleep 0.1 until EventMachine.reactor_running?
          end

          # Create WebSocket connection
          ws_url = @url.sub(/^http/, 'ws')
          @connection = Faye::WebSocket::Client.new(ws_url, nil, headers: @headers)
          
          # Set up WebSocket event handlers
          setup_event_handlers
          
          # Wait for connection to establish
          wait_for_connection
          
          # Return a connection object
          Connection.new(self)
        end

        # Disconnect from the MCP endpoint
        def disconnect
          @connection&.close
          @connection = nil
        end

        # Check if the transport is connected
        # @return [Boolean] true if connected, false otherwise
        def connected?
          !@connection.nil? && @connection.ready_state == Faye::WebSocket::API::OPEN
        end

        # Send a message over the transport
        # @param message [Hash] The message to send
        def send_message(message)
          raise 'Not connected' unless connected?
          
          json = JSON.generate(message)
          @logger.debug("Sending: #{json}")
          @connection.send(json)
          
          # For request messages, store the handler for the response
          if message[:id]
            promise = Promise.new
            @response_handlers[message[:id]] = promise
            promise.get(30) # Wait up to 30 seconds for response
          end
        end
        
        # Register a handler for a specific event type
        # @param event_type [String] The event type to handle
        # @param &block [Proc] The handler block
        def on_event(event_type, &block)
          @event_handlers[event_type] = block
        end
        
        # Set authentication provider and permissions
        # @param auth_provider [MCP::Server::Auth::OAuth] The authentication provider
        # @param permissions [MCP::Server::Auth::Permissions] The permissions manager
        def set_auth_middleware(auth_provider, permissions)
          @auth_provider = auth_provider
          @permissions = permissions
          
          # If this is a server transport, need to integrate with Rack middleware
          setup_auth_middleware if server_mode?
        end
        
        # Set the authentication token for client requests
        # @param token [String] The authentication token
        def set_auth_token(token)
          @auth_token = token
          add_auth_header
          
          # Update connection if already established
          reconnect_with_auth if connected?
        end
        
        # Refresh the authentication token
        # @param token [String] The new authentication token
        def refresh_auth_token(token)
          set_auth_token(token)
        end

        private
        
        # Check if this transport is in server mode
        # @return [Boolean] true if in server mode
        def server_mode?
          @options[:mode] == :server
        end
        
        # Add authentication header
        def add_auth_header
          return unless @auth_token
          @headers['Authorization'] = "Bearer #{@auth_token}"
        end
        
        # Reconnect with updated authentication
        def reconnect_with_auth
          disconnect
          connect
        end
        
        # Setup authentication middleware for server mode
        def setup_auth_middleware
          return unless server_mode? && @auth_provider && @permissions
          
          # The actual middleware setup will depend on the server implementation
          # This will be integrated with the HTTP server framework being used
          # (e.g., Rack, Sinatra, Rails)
          @logger.info("Authentication middleware configured with provider: #{@auth_provider.class.name}")
        end

        # Set up WebSocket event handlers
        def setup_event_handlers
          @connection.on :open do |_|
            @logger.info("Connection established")
            @request_queue << true # Signal that connection is ready
          end

          @connection.on :message do |event|
            handle_message(event.data)
          end

          @connection.on :close do |event|
            @logger.info("Connection closed: #{event.code} #{event.reason}")
            
            # Handle authentication errors
            if event.code == 1008
              handle_auth_error(event.reason)
            end
            
            @connection = nil
          end

          @connection.on :error do |event|
            @logger.error("Connection error: #{event.message}")
          end
        end
        
        # Handle authentication errors
        # @param reason [String] The error reason
        def handle_auth_error(reason)
          if reason.include?('token expired') && @auth_provider && @options[:auto_refresh]
            @logger.info("Authentication token expired, attempting to refresh")
            
            # Trigger token refresh if configured
            if @event_handlers['auth.refresh']
              @event_handlers['auth.refresh'].call
            end
          end
        end

        # Wait for connection to establish
        def wait_for_connection
          # Wait up to 10 seconds for connection to establish
          10.times do
            begin
              @request_queue.pop(non_block: true)
              return
            rescue ThreadError
              sleep 1
            end
          end
          
          raise 'Connection timeout'
        end

        # Handle an incoming message
        # @param data [String] The raw message data
        def handle_message(data)
          begin
            message = JSON.parse(data, symbolize_names: true)
            @logger.debug("Received: #{message}")
            
            # Handle response messages
            if message[:id] && (message[:result] || message[:error])
              promise = @response_handlers.delete(message[:id])
              if promise
                if message[:error]
                  # Check for authentication errors
                  if message[:error][:code] == -32000 && 
                     message[:error][:message]&.include?('authentication')
                    handle_auth_message_error(message[:error])
                  end
                  
                  promise.reject(message[:error])
                else
                  promise.resolve(message[:result])
                end
              end
            end
            
            # Handle notification messages
            if message[:method] && !message[:id]
              method = message[:method]
              handler = @event_handlers[method]
              handler&.call(message[:params])
            end
          rescue JSON::ParserError => e
            @logger.error("Error parsing message: #{e.message}")
          end
        end
        
        # Handle authentication errors in messages
        # @param error [Hash] The error data
        def handle_auth_message_error(error)
          if error[:message].include?('token expired') && @options[:auto_refresh]
            @logger.info("Authentication token expired, attempting to refresh")
            
            # Trigger token refresh if configured
            if @event_handlers['auth.refresh']
              @event_handlers['auth.refresh'].call
            end
          end
        end
      end

      # Promise implementation for asynchronous operations
      class Promise
        def initialize
          @mutex = Mutex.new
          @condition = ConditionVariable.new
          @fulfilled = false
          @rejected = false
          @value = nil
          @reason = nil
        end

        def resolve(value)
          @mutex.synchronize do
            return if @fulfilled || @rejected
            
            @fulfilled = true
            @value = value
            @condition.broadcast
          end
        end

        def reject(reason)
          @mutex.synchronize do
            return if @fulfilled || @rejected
            
            @rejected = true
            @reason = reason
            @condition.broadcast
          end
        end

        def get(timeout = nil)
          @mutex.synchronize do
            unless @fulfilled || @rejected
              @condition.wait(@mutex, timeout)
            end
            
            if @rejected
              raise @reason
            elsif @fulfilled
              @value
            else
              raise 'Promise timed out'
            end
          end
        end
      end
    end
  end
end