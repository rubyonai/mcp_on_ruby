# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'MCP::Protocol::Transport::HTTP' do
  let(:http_class) { MCP::Protocol::Transport::HTTP }
  let(:url) { 'http://localhost:3000/mcp' }
  let(:headers) { { 'X-API-Key' => 'test-key' } }
  let(:transport) { http_class.new(url: url, headers: headers) }
  
  before do
    # Stub EventMachine
    allow(EventMachine).to receive(:reactor_running?).and_return(true)
    
    # Stub Queue
    queue = Queue.new
    allow(Queue).to receive(:new).and_return(queue)
    allow(queue).to receive(:pop).and_return(true) # Make wait_for_connection succeed
    
    # Stub WebSocket
    websocket = double(
      on: nil,
      send: nil,
      close: nil,
      ready_state: Faye::WebSocket::API::OPEN
    )
    stub_const('Faye::WebSocket::API::OPEN', 1)
    stub_const('Faye::WebSocket::Client', Class.new)
    allow(Faye::WebSocket::Client).to receive(:new).and_return(websocket)
    
    # Mock Promise
    promise = double
    allow(promise).to receive(:get).and_return({})
    stub_const('Promise', Class.new)
    allow(Promise).to receive(:new).and_return(promise)
  end
  
  describe '#initialize' do
    it 'sets the URL and headers' do
      expect(transport.url).to eq(url)
      expect(transport.headers).to eq(headers)
    end
    
    it 'uses default values if not provided' do
      transport = http_class.new
      expect(transport.url).to eq('http://localhost:3000/mcp')
      expect(transport.headers).to be_a(Hash)
      expect(transport.headers).to be_empty
    end
  end
  
  describe '#connected?' do
    context 'when connection is not established' do
      before do
        transport.instance_variable_set(:@connection, nil)
      end
      
      it 'returns false' do
        expect(transport.connected?).to be(false)
      end
    end
    
    context 'when connection is established' do
      before do
        websocket = double(ready_state: Faye::WebSocket::API::OPEN)
        transport.instance_variable_set(:@connection, websocket)
      end
      
      it 'returns true' do
        expect(transport.connected?).to be(true)
      end
    end
  end
  
  describe '#on_event' do
    let(:event_type) { :message }
    let(:handler) { proc {} }
    
    it 'adds an event handler' do
      transport.on_event(event_type, &handler)
      handlers = transport.instance_variable_get(:@event_handlers)
      expect(handlers[event_type]).to eq(handler)
    end
  end
end