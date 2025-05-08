# frozen_string_literal: true

RSpec.describe MCP::Client::Client do
  let(:options) do
    {
      url: 'http://localhost:3000/mcp',
      logger: Logger.new(nil)
    }
  end
  
  let(:client) { described_class.new(options) }
  let(:transport) { MockTransport.new }
  let(:connection) { MockConnection.new(transport) }
  
  before do
    allow(MCP::Protocol).to receive(:create_transport).and_return(transport)
    allow(MCP::Protocol).to receive(:connect).and_return(connection)
    
    # Set server info
    client.instance_variable_set(:@server_info, {
      name: 'Test Server',
      version: '1.0.0'
    })
  end
  
  describe '#initialize' do
    it 'sets client properties' do
      expect(client.url).to eq('http://localhost:3000/mcp')
      expect(client.options).to eq(options)
    end
    
    it 'uses default URL if not provided' do
      client = described_class.new
      expect(client.url).to eq('http://localhost:3000/mcp')
    end
    
    it 'initializes transport options' do
      transport_options = client.instance_variable_get(:@transport_options)
      expect(transport_options[:url]).to eq('http://localhost:3000/mcp')
      expect(transport_options[:transport]).to eq(:http)
    end
  end
  
  describe '#connect' do
    it 'creates a transport and establishes connection' do
      expect(MCP::Protocol).to receive(:create_transport).and_return(transport)
      expect(MCP::Protocol).to receive(:connect).and_return(connection)
      
      client.connect
    end
    
    it 'initializes the connection' do
      expect(connection).to receive(:initialize_connection)
      
      client.connect
    end
    
    it 'sets connected flag to true' do
      client.connect
      expect(client.connected?).to be(true)
    end
    
    it 'stores server info' do
      server_info = { name: 'Server', version: '1.0' }
      allow(connection).to receive(:initialize_connection).and_return({
        serverInfo: server_info,
        protocolVersion: '2025-03-26'
      })
      
      client.connect
      expect(client.server_info).to eq(server_info)
    end
    
    it 'raises error if already connected' do
      client.instance_variable_set(:@connected, true)
      
      expect {
        client.connect
      }.to raise_error(MCP::Errors::ConnectionError)
    end
  end
  
  describe '#disconnect' do
    before do
      client.instance_variable_set(:@connected, true)
      client.instance_variable_set(:@connection, connection)
    end
    
    it 'disconnects the transport' do
      expect(transport).to receive(:disconnect)
      client.disconnect
    end
    
    it 'sets connected flag to false' do
      client.disconnect
      expect(client.connected?).to be(false)
    end
    
    it 'clears connection and server info' do
      client.disconnect
      expect(client.instance_variable_get(:@connection)).to be_nil
      expect(client.instance_variable_get(:@server_info)).to be_nil
    end
    
    it 'does nothing if not connected' do
      client.instance_variable_set(:@connected, false)
      
      expect(transport).not_to receive(:disconnect)
      client.disconnect
    end
  end
  
  describe '#call_method' do
    before do
      client.instance_variable_set(:@connected, true)
      client.instance_variable_set(:@connection, connection)
    end
    
    it 'validates connection before calling' do
      client.instance_variable_set(:@connected, false)
      
      expect {
        client.call_method('test/method')
      }.to raise_error(MCP::Errors::ConnectionError)
    end
    
    it 'sends a request through the connection' do
      expect(connection).to receive(:send_request).with('test/method', { param: 'value' })
      
      client.call_method('test/method', { param: 'value' })
    end
    
    it 'uses retry mechanism if enabled' do
      client.instance_variable_set(:@retry_enabled, true)
      expect(client).to receive(:with_retry).and_yield
      expect(connection).to receive(:send_request)
      
      client.call_method('test/method')
    end
  end
  
  describe '#send_notification' do
    before do
      client.instance_variable_set(:@connected, true)
      client.instance_variable_set(:@connection, connection)
    end
    
    it 'validates connection before sending' do
      client.instance_variable_set(:@connected, false)
      
      expect {
        client.send_notification('test/event')
      }.to raise_error(MCP::Errors::ConnectionError)
    end
    
    it 'sends a notification through the connection' do
      expect(connection).to receive(:send_notification).with('test/event', { param: 'value' })
      
      client.send_notification('test/event', { param: 'value' })
    end
  end
  
  describe '#on_event' do
    before do
      client.instance_variable_set(:@connected, true)
      client.instance_variable_set(:@connection, connection)
    end
    
    it 'registers event handler with the connection' do
      handler = Proc.new {}
      expect(connection).to receive(:on_event).with('test_event', &handler)
      
      client.on_event('test_event', &handler)
    end
    
    it 'validates connection before registering' do
      client.instance_variable_set(:@connected, false)
      
      expect {
        client.on_event('test_event') {}
      }.to raise_error(MCP::Errors::ConnectionError)
    end
  end
  
  describe '#ping' do
    before do
      client.instance_variable_set(:@connected, true)
      client.instance_variable_set(:@connection, connection)
    end
    
    it 'sends ping request through connection' do
      expect(connection).to receive(:ping)
      client.ping
    end
    
    it 'validates connection before pinging' do
      client.instance_variable_set(:@connected, false)
      
      expect {
        client.ping
      }.to raise_error(MCP::Errors::ConnectionError)
    end
  end
  
  describe '#enable_retry' do
    it 'enables retry mechanism with default options' do
      client.enable_retry
      
      expect(client.instance_variable_get(:@retry_enabled)).to be(true)
      expect(client.instance_variable_get(:@max_retries)).to eq(3)
      expect(client.instance_variable_get(:@base_delay)).to eq(1.0)
      expect(client.instance_variable_get(:@max_delay)).to eq(10.0)
    end
    
    it 'enables retry mechanism with custom options' do
      client.enable_retry(max_retries: 5, base_delay: 0.5, max_delay: 5.0)
      
      expect(client.instance_variable_get(:@retry_enabled)).to be(true)
      expect(client.instance_variable_get(:@max_retries)).to eq(5)
      expect(client.instance_variable_get(:@base_delay)).to eq(0.5)
      expect(client.instance_variable_get(:@max_delay)).to eq(5.0)
    end
  end
  
  describe '#disable_retry' do
    it 'disables retry mechanism' do
      client.instance_variable_set(:@retry_enabled, true)
      client.disable_retry
      
      expect(client.instance_variable_get(:@retry_enabled)).to be(false)
    end
  end
  
  describe '#validate_connection' do
    it 'raises ConnectionError if not connected' do
      client.instance_variable_set(:@connected, false)
      
      expect {
        client.send(:validate_connection)
      }.to raise_error(MCP::Errors::ConnectionError, /Not connected/)
    end
    
    it 'does nothing if connected' do
      client.instance_variable_set(:@connected, true)
      
      expect {
        client.send(:validate_connection)
      }.not_to raise_error
    end
  end
end