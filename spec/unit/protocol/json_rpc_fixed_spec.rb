# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'JSON-RPC Protocol' do
  let(:json_rpc_class) { MCP::Protocol::JsonRPC }
  
  describe '.request' do
    it 'creates a valid JSON-RPC 2.0 request' do
      id = SecureRandom.uuid
      request = json_rpc_class.request('test/method', { param1: 'value1' }, id)
      
      expect(request[:jsonrpc]).to eq('2.0')
      expect(request[:method]).to eq('test/method')
      expect(request[:params]).to eq({ param1: 'value1' })
      expect(request[:id]).to eq(id)
    end
    
    it 'generates an ID if not provided' do
      request = json_rpc_class.request('test/method')
      
      expect(request[:id]).not_to be_nil
      expect(request[:id]).to be_a(String)
    end
    
    it 'omits params if nil' do
      request = json_rpc_class.request('test/method', nil)
      
      expect(request).not_to have_key(:params)
    end
  end
  
  describe '.notification' do
    it 'creates a valid notification without an ID' do
      notification = json_rpc_class.notification('test/event', { data: 'value' })
      
      expect(notification[:jsonrpc]).to eq('2.0')
      expect(notification[:method]).to eq('test/event')
      expect(notification[:params]).to eq({ data: 'value' })
      expect(notification).not_to have_key(:id)
    end
  end
end