# frozen_string_literal: true

RSpec.describe "Basic client-server integration" do
  let(:server) { MCP::Server::Server.new(name: 'Test Server') }
  let(:client) { MCP::Client::Client.new(url: 'http://localhost:3000/mcp') }
  
  before(:all) do
    # Start a server in a separate thread for integration tests
    # This simulates the server side using the STDIO transport to avoid needing a real HTTP server
    @server_thread = Thread.new do
      server = MCP::Server::Server.new(
        name: 'Test Integration Server',
        transport_options: {
          transport: :stdio,
          stdin: StringIO.new,
          stdout: StringIO.new
        }
      )
      
      # Define a test tool
      server.instance_variable_get(:@method_handlers)['tools/list'] = lambda do |_params|
        [
          {
            name: 'test.echo',
            schema: {
              type: 'object',
              properties: {
                message: { type: 'string' }
              },
              required: ['message']
            }
          }
        ]
      end
      
      server.instance_variable_get(:@method_handlers)['tools/call'] = lambda do |params|
        if params[:name] == 'test.echo'
          { message: params[:parameters][:message] }
        else
          { error: 'Tool not found' }
        end
      end
      
      # Start the server and keep it running
      server.start
      
      # Keep the thread alive until the tests are done
      sleep
    end
    
    # Give the server time to start
    sleep 0.1
  end
  
  after(:all) do
    # Stop the server thread after tests
    @server_thread.kill if @server_thread
  end
  
  # For individual tests, we'll mock the connection
  # since we don't want to actually connect to a server
  before do
    # Mock the connection for client
    allow(MCP::Protocol).to receive(:connect).and_return(
      double(
        'Connection',
        initialize_connection: {
          serverInfo: {
            name: 'Test Server',
            version: '1.0.0'
          },
          protocolVersion: MCP::PROTOCOL_VERSION,
          capabilities: {}
        },
        send_request: nil
      )
    )
  end
  
  describe "client-server connection" do
    it "connects to the server and gets server info" do
      # Mock the connection's send_request for this test
      connection = double(
        'Connection',
        initialize_connection: {
          serverInfo: {
            name: 'Test Server',
            version: '1.0.0'
          },
          protocolVersion: MCP::PROTOCOL_VERSION,
          capabilities: {}
        }
      )
      allow(MCP::Protocol).to receive(:connect).and_return(connection)
      
      # Connect the client
      client.connect
      
      # Verify server info was received
      expect(client.server_info).to include(:name, :version)
      expect(client.server_info[:name]).to eq('Test Server')
      expect(client.connected?).to be(true)
    end
    
    it "disconnects from the server" do
      # Create a test double for the transport
      transport = double('Transport', disconnect: nil)
      
      # Mock the connection's initialize_connection and transport
      connection = double(
        'Connection',
        initialize_connection: {
          serverInfo: {
            name: 'Test Server',
            version: '1.0.0'
          },
          protocolVersion: MCP::PROTOCOL_VERSION,
          capabilities: {}
        },
        transport: transport
      )
      allow(MCP::Protocol).to receive(:connect).and_return(connection)
      
      # Connect and then disconnect
      client.connect
      client.disconnect
      
      # Verify disconnect was called and client state updated
      expect(transport).to have_received(:disconnect)
      expect(client.connected?).to be(false)
      expect(client.server_info).to be_nil
    end
  end
  
  describe "method calls" do
    # Mock connection with specific responses
    let(:connection) do
      double(
        'Connection',
        initialize_connection: {
          serverInfo: {
            name: 'Test Server',
            version: '1.0.0'
          },
          protocolVersion: MCP::PROTOCOL_VERSION,
          capabilities: {}
        }
      )
    end
    
    before do
      allow(MCP::Protocol).to receive(:connect).and_return(connection)
      client.connect
    end
    
    it "lists available tools" do
      # Mock the tools/list response
      tools_list = [
        {
          name: 'test.echo',
          schema: {
            type: 'object',
            properties: {
              message: { type: 'string' }
            },
            required: ['message']
          }
        }
      ]
      
      allow(connection).to receive(:send_request).with('tools/list', anything).and_return(tools_list)
      
      # Call the method through the client
      result = client.call_method('tools/list')
      
      # Verify the result
      expect(result).to be_an(Array)
      expect(result.length).to eq(1)
      expect(result.first[:name]).to eq('test.echo')
    end
    
    it "calls a tool" do
      # Mock the tools/call response
      tool_result = { message: 'Hello, world!' }
      
      allow(connection).to receive(:send_request).with('tools/call', anything).and_return(tool_result)
      
      # Call the method through the client
      result = client.call_method('tools/call', {
        name: 'test.echo',
        parameters: { message: 'Hello, world!' }
      })
      
      # Verify the result
      expect(result).to eq(tool_result)
    end
    
    it "sends a notification" do
      # Just verify that send_notification is called on the connection
      expect(connection).to receive(:send_notification).with('test/notification', { data: 'test' })
      
      client.send_notification('test/notification', { data: 'test' })
    end
  end
  
  describe "error handling" do
    let(:connection) do
      double(
        'Connection',
        initialize_connection: {
          serverInfo: {
            name: 'Test Server',
            version: '1.0.0'
          },
          protocolVersion: MCP::PROTOCOL_VERSION,
          capabilities: {}
        }
      )
    end
    
    before do
      allow(MCP::Protocol).to receive(:connect).and_return(connection)
      client.connect
    end
    
    it "handles method errors" do
      # Mock an error response
      error = {
        code: -32601,
        message: 'Method not found'
      }
      
      allow(connection).to receive(:send_request).with('unknown/method', anything).and_raise(
        MCP::Errors::MethodNotFoundError.new(error[:message])
      )
      
      # Call the method and expect an error
      expect {
        client.call_method('unknown/method')
      }.to raise_error(MCP::Errors::MethodNotFoundError)
    end
    
    it "handles validation errors" do
      # Mock a validation error
      allow(connection).to receive(:send_request).with('tools/call', anything).and_raise(
        MCP::Errors::ValidationError.new('Invalid parameters')
      )
      
      # Call with invalid parameters
      expect {
        client.call_method('tools/call', {
          name: 'test.echo',
          parameters: {} # Missing required 'message' field
        })
      }.to raise_error(MCP::Errors::ValidationError)
    end
  end
  
  describe "retry mechanism" do
    let(:connection) do
      double(
        'Connection',
        initialize_connection: {
          serverInfo: {
            name: 'Test Server',
            version: '1.0.0'
          },
          protocolVersion: MCP::PROTOCOL_VERSION,
          capabilities: {}
        }
      )
    end
    
    before do
      allow(MCP::Protocol).to receive(:connect).and_return(connection)
      client.connect
    end
    
    it "retries failed requests" do
      # Enable retry with minimal delays for testing
      client.enable_retry(max_retries: 2, base_delay: 0.01, max_delay: 0.02)
      
      # Mock a connection error that will succeed on the second try
      call_count = 0
      allow(connection).to receive(:send_request) do |method, params|
        call_count += 1
        if call_count == 1
          raise MCP::Errors::ConnectionError.new('Connection lost')
        else
          { result: 'success' }
        end
      end
      
      # Call the method
      result = client.call_method('test/method')
      
      # Verify that it retried and eventually succeeded
      expect(call_count).to eq(2)
      expect(result).to eq({ result: 'success' })
    end
    
    it "gives up after max retries" do
      # Enable retry with minimal delays for testing
      client.enable_retry(max_retries: 2, base_delay: 0.01, max_delay: 0.02)
      
      # Mock a persistent connection error
      allow(connection).to receive(:send_request).and_raise(
        MCP::Errors::ConnectionError.new('Connection lost')
      )
      
      # Call the method and expect it to fail after retries
      expect {
        client.call_method('test/method')
      }.to raise_error(MCP::Errors::ConnectionError)
      
      # Check that it tried the maximum number of times (3 = initial + 2 retries)
      expect(connection).to have_received(:send_request).exactly(3).times
    end
  end
end