# frozen_string_literal: true

RSpec.describe MCP::Server::Server do
  let(:options) do
    {
      name: 'Test Server',
      logger: Logger.new(nil)
    }
  end
  
  let(:server) { described_class.new(options) }
  let(:transport) { MockTransport.new }
  
  before do
    allow(MCP::Protocol).to receive(:create_server).and_return(transport)
  end
  
  describe '#initialize' do
    it 'sets server properties' do
      expect(server.name).to eq('Test Server')
      expect(server.id).not_to be_nil
      expect(server.options).to eq(options)
    end
    
    it 'uses default name if not provided' do
      server = described_class.new
      expect(server.name).to eq('MCP Ruby Server')
    end
    
    it 'initializes transport' do
      expect(MCP::Protocol).to receive(:create_server)
      described_class.new(options)
    end
    
    it 'sets up default method handlers' do
      handlers = server.instance_variable_get(:@method_handlers)
      expect(handlers.keys).to include('initialize', 'ping')
    end
  end
  
  describe '#start' do
    it 'connects the transport' do
      expect(transport).to receive(:connect)
      server.start
    end
    
    it 'sets running flag to true' do
      server.start
      expect(server.running?).to be(true)
    end
    
    it 'does nothing if already running' do
      server.instance_variable_set(:@running, true)
      
      expect(transport).not_to receive(:connect)
      server.start
    end
  end
  
  describe '#stop' do
    before do
      server.instance_variable_set(:@running, true)
    end
    
    it 'disconnects the transport' do
      expect(transport).to receive(:disconnect)
      server.stop
    end
    
    it 'sets running flag to false' do
      server.stop
      expect(server.running?).to be(false)
    end
    
    it 'does nothing if not running' do
      server.instance_variable_set(:@running, false)
      
      expect(transport).not_to receive(:disconnect)
      server.stop
    end
  end
  
  describe '#on_method' do
    it 'registers a method handler' do
      handler = Proc.new {}
      server.on_method('test/method', &handler)
      
      handlers = server.instance_variable_get(:@method_handlers)
      expect(handlers['test/method']).to eq(handler)
    end
  end
  
  describe '#on_event' do
    it 'registers an event handler' do
      handler = Proc.new {}
      server.on_event(:connection_closed, &handler)
      
      handlers = server.instance_variable_get(:@event_handlers)
      expect(handlers[:connection_closed]).to eq(handler)
    end
  end
  
  describe '#set_auth_provider' do
    let(:auth_provider) { double('OAuth Provider') }
    let(:permissions) { double('Permissions Manager') }
    
    it 'sets the auth provider and permissions' do
      server.set_auth_provider(auth_provider, permissions)
      
      expect(server.instance_variable_get(:@auth_provider)).to eq(auth_provider)
      expect(server.instance_variable_get(:@permissions)).to eq(permissions)
    end
    
    it 'updates the transport if it supports auth middleware' do
      expect(transport).to receive(:respond_to?).with(:set_auth_middleware).and_return(true)
      expect(transport).to receive(:set_auth_middleware).with(auth_provider, permissions)
      
      server.set_auth_provider(auth_provider, permissions)
    end
  end
  
  describe '#handle_rpc_message' do
    let(:handler) { double('Method Handler') }
    let(:message) do
      {
        jsonrpc: '2.0',
        method: 'test/method',
        params: { param1: 'value1' },
        id: '123'
      }
    end
    
    before do
      server.instance_variable_set(:@method_handlers, { 'test/method' => handler })
    end
    
    it 'calls the appropriate method handler' do
      expect(handler).to receive(:call).with({ param1: 'value1' }).and_return({ result: 'success' })
      
      result = server.send(:handle_rpc_message, message)
      expect(result).to eq({ result: 'success' })
    end
    
    it 'returns error for unknown methods' do
      unknown_message = message.merge(method: 'unknown/method')
      
      result = server.send(:handle_rpc_message, unknown_message)
      expect(result).to include(:code, :message)
      expect(result[:code]).to eq(-32601)
    end
    
    it 'returns error if handler raises an exception' do
      expect(handler).to receive(:call).and_raise(StandardError.new('Test error'))
      
      result = server.send(:handle_rpc_message, message)
      expect(result).to include(:code, :message)
      expect(result[:code]).to eq(-32603)
      expect(result[:message]).to include('Test error')
    end
    
    it 'returns nil for notifications' do
      notification = message.dup
      notification.delete(:id)
      
      expect(handler).to receive(:call).with({ param1: 'value1' }).and_return({ result: 'success' })
      
      result = server.send(:handle_rpc_message, notification)
      expect(result).to be_nil
    end
    
    it 'returns nil for invalid message format' do
      result = server.send(:handle_rpc_message, nil)
      expect(result).to be_nil
      
      result = server.send(:handle_rpc_message, 'not a hash')
      expect(result).to be_nil
    end
  end
  
  describe 'default method handlers' do
    describe 'initialize handler' do
      it 'responds with server info' do
        params = {
          protocolVersion: MCP::PROTOCOL_VERSION,
          clientInfo: {
            name: 'Test Client',
            version: '1.0.0'
          }
        }
        
        result = server.instance_variable_get(:@method_handlers)['initialize'].call(params)
        
        expect(result).to include(:serverInfo, :protocolVersion, :capabilities)
        expect(result[:serverInfo]).to include(:name, :version)
        expect(result[:serverInfo][:name]).to eq('Test Server')
        expect(result[:protocolVersion]).to eq(MCP::PROTOCOL_VERSION)
      end
    end
    
    describe 'ping handler' do
      it 'responds with pong' do
        result = server.instance_variable_get(:@method_handlers)['ping'].call({})
        expect(result).to eq({ pong: true })
      end
    end
  end
end