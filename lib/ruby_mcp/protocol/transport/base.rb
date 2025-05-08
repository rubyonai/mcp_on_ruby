# frozen_string_literal: true

require 'logger'

module MCP
  module Protocol
    module Transport
      # Base class for MCP transport implementations
      class Base
        attr_reader :logger

        def initialize(options = {})
          @logger = options[:logger] || Logger.new($stdout)
          @logger.level = options[:log_level] || Logger::INFO
        end

        # Connect to the MCP endpoint
        # @return [Connection] An established connection
        def connect
          raise NotImplementedError, "#{self.class} must implement #connect"
        end

        # Disconnect from the MCP endpoint
        def disconnect
          raise NotImplementedError, "#{self.class} must implement #disconnect"
        end

        # Check if the transport is connected
        # @return [Boolean] true if connected, false otherwise
        def connected?
          raise NotImplementedError, "#{self.class} must implement #connected?"
        end

        # Send a message over the transport
        # @param message [Hash] The message to send
        def send_message(message)
          raise NotImplementedError, "#{self.class} must implement #send_message"
        end

        # Receive a message from the transport
        # @return [Hash] The received message
        def receive_message
          raise NotImplementedError, "#{self.class} must implement #receive_message"
        end
        
        # Stream messages from the transport
        # @yield [Hash] The received message
        def stream_messages
          raise NotImplementedError, "#{self.class} must implement #stream_messages"
        end
      end

      # Base class for MCP transport connections
      class Connection
        attr_reader :transport

        def initialize(transport)
          @transport = transport
        end

        # Send a message over the connection
        # @param message [Hash] The message to send
        def send(message)
          @transport.send_message(message)
        end

        # Receive a message from the connection
        # @return [Hash] The received message
        def receive
          @transport.receive_message
        end

        # Close the connection
        def close
          @transport.disconnect
        end
      end
    end
  end
end