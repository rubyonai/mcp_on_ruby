# frozen_string_literal: true

# Helper methods for testing MCP modules
module MCPTestHelpers
  # Get a mock transport for testing
  # @return [Object] A mock transport
  def mock_transport
    double(
      connect: double,
      connected?: true,
      disconnect: nil,
      on_event: nil,
      send_message: {},
      headers: {},
      stream_messages: nil
    )
  end
  
  # Get a mock connection for testing
  # @return [Object] A mock connection
  def mock_connection
    double(
      initialize_connection: true,
      send_request: {
        jsonrpc: '2.0',
        result: {},
        id: 'mock-id'
      },
      send_notification: nil,
      on_method: nil,
      start: nil,
      stop: nil,
      transport: mock_transport
    )
  end
end