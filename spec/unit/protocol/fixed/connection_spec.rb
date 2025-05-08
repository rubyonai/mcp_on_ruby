# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'MCP::Protocol::Connection' do
  let(:connection_class) { MCP::Protocol::Connection }
  let(:transport) { mock_transport }
  let(:connection) { connection_class.new(transport) }
  
  describe '#initialize' do
    it 'sets the transport' do
      expect(connection.transport).to eq(transport)
    end
  end
  
  describe '#initialize_connection' do
    let(:init_params) do
      {
        client_info: {
          name: 'Test Client',
          version: '1.0.0'
        },
        protocol_version: MCP::PROTOCOL_VERSION
      }
    end
    
    before do
      allow(transport).to receive(:send_message).and_return(nil)
      allow(MCP::Protocol::JsonRPC).to receive(:success).and_return({
        jsonrpc: '2.0',
        result: {},
        id: 'test-id'
      })
    end
    
    it 'sends an initialize request to the transport' do
      expect(transport).to receive(:send_message) do |message|
        expect(message[:method]).to eq('initialize')
        expect(message[:params][:clientInfo]).to eq(init_params[:client_info])
        expect(message[:params][:protocolVersion]).to eq(init_params[:protocol_version])
        expect(message[:id]).not_to be_nil
      end
      
      connection.initialize_connection(init_params)
    end
    
    it 'returns true when successful' do
      result = connection.initialize_connection(init_params)
      expect(result).to eq(true)
    end
    
    it 'sets the initialized flag' do
      connection.initialize_connection(init_params)
      expect(connection.instance_variable_get(:@initialized)).to eq(true)
    end
    
    it 'only initializes once' do
      connection.instance_variable_set(:@initialized, true)
      expect(transport).not_to receive(:send_message)
      
      result = connection.initialize_connection(init_params)
      expect(result).to eq(true)
    end
  end
  
  describe '#send_request' do
    let(:request) do
      {
        jsonrpc: '2.0',
        method: 'test/method',
        params: { param: 'value' },
        id: 'test-id'
      }
    end
    
    before do
      allow(transport).to receive(:send_message).and_return(nil)
      allow(MCP::Protocol::JsonRPC).to receive(:success).and_return({
        jsonrpc: '2.0',
        result: { status: 'ok' },
        id: request[:id]
      })
    end
    
    it 'sends the request through the transport' do
      expect(transport).to receive(:send_message).with(request)
      connection.send_request(request)
    end
    
    it 'returns a success response' do
      response = connection.send_request(request)
      expect(response[:jsonrpc]).to eq('2.0')
      expect(response[:result]).to be_a(Hash)
      expect(response[:id]).to eq(request[:id])
    end
  end
  
  describe '#send_notification' do
    let(:notification) do
      {
        jsonrpc: '2.0',
        method: 'test/event',
        params: { data: 'value' }
      }
    end
    
    it 'sends the notification through the transport' do
      expect(transport).to receive(:send_message).with(notification)
      connection.send_notification(notification)
    end
  end
  
  describe '#on_method' do
    let(:method_name) { 'test_method' }
    let(:handler) { proc {} }
    
    it 'registers a method handler' do
      connection.on_method(method_name, &handler)
      handlers = connection.instance_variable_get(:@message_handlers)
      expect(handlers[method_name]).to eq(handler)
    end
  end
  
  describe '#start' do
    it 'starts streaming messages from the transport' do
      expect(transport).to receive(:stream_messages)
      connection.start
    end
  end
  
  describe '#stop' do
    it 'disconnects the transport' do
      expect(transport).to receive(:disconnect)
      connection.stop
    end
  end
end