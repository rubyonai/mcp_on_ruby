# frozen_string_literal: true

RSpec.describe MCP::Protocol::Connection do
  let(:transport) { MockTransport.new }
  let(:connection) { described_class.new(transport) }
  
  describe '#initialize' do
    it 'sets the transport' do
      expect(connection.transport).to eq(transport)
    end
  end
  
  describe '#initialize_connection' do
    it 'sends the initialize request' do
      connection.initialize_connection
      
      expect(transport.messages.first[:method]).to eq('initialize')
      expect(transport.messages.first[:params]).to include(:clientInfo)
      expect(transport.messages.first[:params][:clientInfo]).to include(:name, :version)
      expect(transport.messages.first[:params][:protocolVersion]).to eq(MCP::PROTOCOL_VERSION)
    end
    
    it 'uses custom client info if provided' do
      client_info = { name: 'Custom Client', version: '1.2.3' }
      connection.initialize_connection(client_info: client_info)
      
      expect(transport.messages.first[:params][:clientInfo]).to eq(client_info)
    end
    
    it 'returns server info from the response' do
      result = connection.initialize_connection
      
      expect(result).to include(:serverInfo)
      expect(result[:serverInfo]).to include(:name, :version)
      expect(result[:protocolVersion]).to eq(MCP::PROTOCOL_VERSION)
    end
  end
  
  describe '#send_request' do
    it 'sends a JSON-RPC request via the transport' do
      connection.send_request('test/method', { param1: 'value1' })
      
      last_message = transport.messages.last
      expect(last_message[:jsonrpc]).to eq('2.0')
      expect(last_message[:method]).to eq('test/method')
      expect(last_message[:params]).to eq({ param1: 'value1' })
      expect(last_message[:id]).to be_a(String)
    end
    
    it 'returns the result from the response' do
      # Modify MockTransport to return a specific result for this test
      allow(transport).to receive(:send_message).and_return({ result: 'test result' })
      
      result = connection.send_request('test/method')
      expect(result).to eq({ result: 'test result' })
    end
  end
  
  describe '#send_notification' do
    it 'sends a JSON-RPC notification via the transport' do
      connection.send_notification('test/notify', { event: 'something happened' })
      
      last_message = transport.messages.last
      expect(last_message[:jsonrpc]).to eq('2.0')
      expect(last_message[:method]).to eq('test/notify')
      expect(last_message[:params]).to eq({ event: 'something happened' })
      expect(last_message[:id]).to be_nil
    end
  end
  
  describe '#on_event' do
    it 'registers an event handler with the transport' do
      handler = Proc.new {}
      expect(transport).to receive(:on_event).with('test_event', &handler)
      
      connection.on_event('test_event', &handler)
    end
  end
  
  describe '#ping' do
    it 'sends a ping request' do
      connection.ping
      
      last_message = transport.messages.last
      expect(last_message[:method]).to eq('ping')
    end
    
    it 'returns the pong response' do
      # Modify MockTransport to return a pong for this test
      allow(transport).to receive(:send_message).and_return({ pong: true })
      
      result = connection.ping
      expect(result).to eq({ pong: true })
    end
  end
end