# frozen_string_literal: true

RSpec.describe MCP::Protocol::Transport::HTTP do
  let(:url) { 'http://localhost:3000/mcp' }
  let(:headers) { { 'X-API-Key' => 'test-key' } }
  let(:transport) { described_class.new(url: url, headers: headers) }
  
  before do
    # Stub WebSocket
    stub_const('Faye::WebSocket::Client', double)
    allow(Faye::WebSocket::Client).to receive(:new).and_return(double(
      on: nil,
      send: nil,
      close: nil,
      ready_state: Faye::WebSocket::API::OPEN
    ))
    
    # Stub EventMachine
    stub_const('EventMachine', double(reactor_running?: true, run: nil))
  end
  
  describe '#initialize' do
    it 'sets the URL and headers' do
      expect(transport.url).to eq(url)
      expect(transport.headers).to eq(headers)
    end
    
    it 'uses default URL if not provided' do
      transport = described_class.new
      expect(transport.url).to eq('http://localhost:3000/mcp')
    end
    
    it 'uses empty headers if not provided' do
      transport = described_class.new
      expect(transport.headers).to eq({})
    end
    
    it 'initializes authentication if token provided' do
      transport = described_class.new(url: url, auth_token: 'test-token')
      expect(transport.headers['Authorization']).to eq('Bearer test-token')
    end
  end
  
  describe '#connect' do
    before do
      # Mock the Queue to avoid blocking in tests
      allow_any_instance_of(Queue).to receive(:pop).and_return(true)
    end
    
    it 'creates a WebSocket connection' do
      expect(Faye::WebSocket::Client).to receive(:new).with(
        'ws://localhost:3000/mcp',
        nil,
        headers: headers
      )
      
      transport.connect
    end
    
    it 'starts EventMachine if not running' do
      allow(EventMachine).to receive(:reactor_running?).and_return(false)
      expect(EventMachine).to receive(:run)
      
      # Mock Thread.new to avoid actually creating a thread
      thread = double
      allow(Thread).to receive(:new).and_yield.and_return(thread)
      
      transport.connect
    end
    
    it 'returns a connection object' do
      connection = transport.connect
      expect(connection).to be_a(MCP::Protocol::Connection)
    end
  end
  
  describe '#disconnect' do
    it 'closes the WebSocket connection' do
      connection = double(close: nil)
      allow(transport).to receive(:connection).and_return(connection)
      
      expect(connection).to receive(:close)
      transport.disconnect
    end
    
    it 'sets connection to nil' do
      connection = double(close: nil)
      allow(transport).to receive(:connection).and_return(connection)
      
      transport.disconnect
      expect(transport.instance_variable_get(:@connection)).to be_nil
    end
  end
  
  describe '#connected?' do
    it 'returns true if connection exists and is open' do
      allow(transport).to receive(:connection).and_return(double(
        ready_state: Faye::WebSocket::API::OPEN
      ))
      
      expect(transport.connected?).to be(true)
    end
    
    it 'returns false if connection does not exist' do
      allow(transport).to receive(:connection).and_return(nil)
      expect(transport.connected?).to be(false)
    end
    
    it 'returns false if connection is not open' do
      allow(transport).to receive(:connection).and_return(double(
        ready_state: Faye::WebSocket::API::CLOSED
      ))
      
      expect(transport.connected?).to be(false)
    end
  end
  
  describe '#send_message' do
    let(:message) { { jsonrpc: '2.0', method: 'test', id: '123' } }
    let(:connection) { double(send: nil, ready_state: Faye::WebSocket::API::OPEN) }
    
    before do
      allow(transport).to receive(:connection).and_return(connection)
      
      # Stub Promise to avoid blocking in tests
      promise = double(get: nil)
      allow(MCP::Protocol::Transport::Promise).to receive(:new).and_return(promise)
    end
    
    it 'raises an error if not connected' do
      allow(transport).to receive(:connected?).and_return(false)
      
      expect {
        transport.send_message(message)
      }.to raise_error('Not connected')
    end
    
    it 'sends the message as JSON' do
      expect(connection).to receive(:send).with(JSON.generate(message))
      transport.send_message(message)
    end
    
    it 'creates a promise for requests with ID' do
      expect(MCP::Protocol::Transport::Promise).to receive(:new)
      transport.send_message(message)
    end
    
    it 'does not create a promise for notifications without ID' do
      notification = { jsonrpc: '2.0', method: 'test' }
      
      expect(MCP::Protocol::Transport::Promise).not_to receive(:new)
      transport.send_message(notification)
    end
  end
  
  describe '#on_event' do
    it 'registers an event handler' do
      handler = Proc.new {}
      transport.on_event('test_event', &handler)
      
      handlers = transport.instance_variable_get(:@event_handlers)
      expect(handlers['test_event']).to eq(handler)
    end
  end
  
  describe '#set_auth_token' do
    it 'updates the auth token in headers' do
      transport.set_auth_token('new-token')
      expect(transport.headers['Authorization']).to eq('Bearer new-token')
    end
    
    it 'reconnects if already connected' do
      allow(transport).to receive(:connected?).and_return(true)
      expect(transport).to receive(:disconnect)
      expect(transport).to receive(:connect)
      
      transport.set_auth_token('new-token')
    end
  end
end

# Promise tests
RSpec.describe MCP::Protocol::Transport::Promise do
  let(:promise) { described_class.new }
  
  describe '#resolve' do
    it 'sets the value and marks as fulfilled' do
      promise.resolve('test value')
      
      expect(promise.instance_variable_get(:@value)).to eq('test value')
      expect(promise.instance_variable_get(:@fulfilled)).to be(true)
    end
    
    it 'does nothing if already fulfilled' do
      promise.resolve('first value')
      promise.resolve('second value')
      
      expect(promise.instance_variable_get(:@value)).to eq('first value')
    end
    
    it 'does nothing if already rejected' do
      promise.reject('error')
      promise.resolve('value')
      
      expect(promise.instance_variable_get(:@value)).to be_nil
      expect(promise.instance_variable_get(:@fulfilled)).to be(false)
    end
  end
  
  describe '#reject' do
    it 'sets the reason and marks as rejected' do
      promise.reject('error reason')
      
      expect(promise.instance_variable_get(:@reason)).to eq('error reason')
      expect(promise.instance_variable_get(:@rejected)).to be(true)
    end
    
    it 'does nothing if already rejected' do
      promise.reject('first error')
      promise.reject('second error')
      
      expect(promise.instance_variable_get(:@reason)).to eq('first error')
    end
    
    it 'does nothing if already fulfilled' do
      promise.resolve('value')
      promise.reject('error')
      
      expect(promise.instance_variable_get(:@reason)).to be_nil
      expect(promise.instance_variable_get(:@rejected)).to be(false)
    end
  end
  
  describe '#get' do
    context 'when fulfilled' do
      it 'returns the value' do
        promise.resolve('test value')
        expect(promise.get).to eq('test value')
      end
    end
    
    context 'when rejected' do
      it 'raises the reason as an error' do
        promise.reject('error reason')
        
        expect {
          promise.get
        }.to raise_error('error reason')
      end
    end
    
    context 'with timeout' do
      it 'raises a timeout error if not fulfilled or rejected' do
        # Override wait to avoid blocking in tests
        allow_any_instance_of(ConditionVariable).to receive(:wait) do |_, _, timeout|
          # Do nothing, simulating a timeout
        end
        
        expect {
          promise.get(0.1)
        }.to raise_error('Promise timed out')
      end
    end
  end
end