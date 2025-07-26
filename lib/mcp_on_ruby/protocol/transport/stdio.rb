# frozen_string_literal: true

require 'json'
require 'thread'

module MCP
  module Protocol
    module Transport
      # STDIO transport for MCP
      class STDIO < Base
        def initialize(options = {})
          super
          @input = options[:input] || $stdin
          @output = options[:output] || $stdout
          @reader_thread = nil
          @message_queue = Queue.new
          @running = false
        end

        # Connect to the MCP endpoint using STDIO
        # @return [Connection] An established connection
        def connect
          return Connection.new(self) if connected?
          
          @running = true
          
          # Start the reader thread
          @reader_thread = Thread.new do
            while @running
              begin
                line = @input.gets
                
                # Exit if EOF
                break unless line
                
                # Skip empty lines
                next if line.strip.empty?
                
                # Parse the message
                message = JSON.parse(line, symbolize_names: true)
                
                # Queue the message
                @message_queue << message
              rescue JSON::ParserError => e
                @logger.error("Error parsing message: #{e.message}")
              rescue => e
                @logger.error("Error reading from STDIO: #{e.message}")
                break
              end
            end
          end
          
          Connection.new(self)
        end

        # Disconnect from the MCP endpoint
        def disconnect
          @running = false
          @reader_thread&.join(2) # Wait up to 2 seconds for reader thread to exit
          @reader_thread = nil
        end

        # Check if the transport is connected
        # @return [Boolean] true if connected, false otherwise
        def connected?
          @running && @reader_thread&.alive?
        end

        # Send a message over the transport
        # @param message [Hash] The message to send
        def send_message(message)
          json = JSON.generate(message)
          @logger.debug("Sending: #{json}")
          @output.puts(json)
          @output.flush
        end

        # Receive a message from the transport
        # @return [Hash] The received message
        def receive_message
          @message_queue.pop
        end
        
        # Stream messages from the transport
        # @yield [Hash] The received message
        def stream_messages
          while connected?
            begin
              message = @message_queue.pop(true)
              yield message
            rescue ThreadError
              # Queue is empty, sleep a bit
              sleep 0.01
            end
          end
        end
      end
    end
  end
end