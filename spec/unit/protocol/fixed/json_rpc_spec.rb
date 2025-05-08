# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'MCP::Protocol::JsonRPC' do
  let(:json_rpc) { MCP::Protocol::JsonRPC }

  describe '.request' do
    it 'creates a valid JSON-RPC 2.0 request' do
      id = SecureRandom.uuid
      request = json_rpc.request('test/method', { param1: 'value1' }, id)
      
      expect(request[:jsonrpc]).to eq('2.0')
      expect(request[:method]).to eq('test/method')
      expect(request[:params]).to eq({ param1: 'value1' })
      expect(request[:id]).to eq(id)
    end
    
    it 'generates an ID if not provided' do
      request = json_rpc.request('test/method')
      
      expect(request[:id]).not_to be_nil
      expect(request[:id]).to be_a(String)
    end
    
    it 'omits params if nil' do
      request = json_rpc.request('test/method', nil)
      
      expect(request).not_to have_key(:params)
    end
  end
  
  describe '.notification' do
    it 'creates a valid notification without an ID' do
      notification = json_rpc.notification('test/event', { data: 'value' })
      
      expect(notification[:jsonrpc]).to eq('2.0')
      expect(notification[:method]).to eq('test/event')
      expect(notification[:params]).to eq({ data: 'value' })
      expect(notification).not_to have_key(:id)
    end
  end
  
  describe '.success' do
    it 'creates a valid success response' do
      id = '123'
      result = { status: 'ok' }
      response = json_rpc.success(id, result)
      
      expect(response[:jsonrpc]).to eq('2.0')
      expect(response[:result]).to eq(result)
      expect(response[:id]).to eq(id)
      expect(response).not_to have_key(:error)
    end
  end
  
  describe '.error' do
    it 'creates a valid error response' do
      id = '123'
      code = -32000
      message = 'Test error'
      data = { details: 'Something went wrong' }
      
      response = json_rpc.error(id, code, message, data)
      
      expect(response[:jsonrpc]).to eq('2.0')
      expect(response[:error][:code]).to eq(code)
      expect(response[:error][:message]).to eq(message)
      expect(response[:error][:data]).to eq(data)
      expect(response[:id]).to eq(id)
      expect(response).not_to have_key(:result)
    end
    
    it 'omits data if nil' do
      response = json_rpc.error('123', -32000, 'Test error')
      
      expect(response[:error]).not_to have_key(:data)
    end
  end
  
  describe '.parse' do
    it 'parses a valid JSON string' do
      json = '{"jsonrpc":"2.0","method":"test","id":"123"}'
      parsed = json_rpc.parse(json)
      
      expect(parsed).to eq({
        jsonrpc: '2.0',
        method: 'test',
        id: '123'
      })
    end
    
    it 'returns an error for invalid JSON' do
      json = '{invalid json}'
      result = json_rpc.parse(json)
      
      expect(result[:error][:code]).to eq(MCP::Protocol::JsonRPC::ErrorCode::PARSE_ERROR)
      expect(result[:error][:message]).to eq('Parse error')
    end
  end
  
  describe '.validate_request' do
    it 'returns nil for a valid request' do
      request = { jsonrpc: '2.0', method: 'test', id: '123' }
      expect(json_rpc.validate_request(request)).to be_nil
    end
    
    it 'returns an error for an invalid request' do
      invalid_requests = [
        'not a hash',
        { method: 'test', id: '123' }, # Missing jsonrpc
        { jsonrpc: '1.0', method: 'test', id: '123' }, # Wrong version
        { jsonrpc: '2.0', method: 123, id: '123' }, # Method not a string
        { jsonrpc: '2.0', method: 'rpc.test', id: '123' } # Method starts with rpc.
      ]
      
      invalid_requests.each do |request|
        result = json_rpc.validate_request(request)
        expect(result).to be_a(Hash)
        expect(result[:error][:code]).to eq(MCP::Protocol::JsonRPC::ErrorCode::INVALID_REQUEST)
      end
    end
  end
end