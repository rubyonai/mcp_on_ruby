# frozen_string_literal: true

require 'uri'
require 'net/http'
require 'json'
require 'securerandom'
require 'faye/websocket'
require 'eventmachine'

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

        private

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
            @connection = nil
          end

          @connection.on :error do |event|
            @logger.error("Connection error: #{event.message}")
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