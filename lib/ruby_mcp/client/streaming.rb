# frozen_string_literal: true

module MCP
  module Client
    # Streaming functionality for the client
    module Streaming
      # Stream a tool call on the server
      # @param name [String] The name of the tool to call
      # @param arguments [Hash] The arguments to pass to the tool
      # @yield [Hash] Each content chunk as it arrives
      # @return [Array<Hash>] The complete content when done
      def stream_tool(name, arguments = {})
        ensure_connected
        
        result_content = []
        
        # Create a streaming-ready request
        request = MCP::Protocol::JsonRPC.request('tools/call', {
          name: name,
          arguments: arguments,
          stream: true
        })
        
        # Set up streaming handlers
        on_event(:content_chunk) do |chunk|
          result_content << chunk
          yield chunk if block_given?
        end
        
        # Send the request
        response = @connection.send_request(request)
        
        if response[:error]
          raise MCP::Errors::ClientError, "Error streaming tool: #{response[:error][:message]}"
        end
        
        # Return the complete content
        result_content
      end
      
      # Add streaming capabilities to a client
      # @param client [MCP::Client::Client] The client to add streaming to
      def self.included(client)
        unless client.included_modules.include?(self)
          client.include(self)
        end
      end
    end
  end
end