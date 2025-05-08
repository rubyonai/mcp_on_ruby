# frozen_string_literal: true

RSpec.describe MCP::Protocol::JsonRPC do
  describe '.request' do
    it 'creates a valid JSON-RPC 2.0 request' do
      id = SecureRandom.uuid
      request = described_class.request('test/method', { param1: 'value1' }, id)
      
      expect(request[:jsonrpc]).to eq('2.0')
      expect(request[:method]).to eq('test/method')
      expect(request[:params]).to eq({ param1: 'value1' })
      expect(request[:id]).to eq(id)
    end
    
    it 'generates a random UUID if id is not provided' do
      request = described_class.request('test/method')
      
      expect(request[:jsonrpc]).to eq('2.0')
      expect(request[:method]).to eq('test/method')
      expect(request[:id]).to be_a(String)
      expect(request[:id]).not_to be_empty
    end
    
    it 'omits params if not provided' do
      request = described_class.request('test/method')
      
      expect(request[:jsonrpc]).to eq('2.0')
      expect(request[:method]).to eq('test/method')
      expect(request[:params]).to be_nil
    end
  end
  
  describe '.notification' do
    it 'creates a valid JSON-RPC 2.0 notification' do
      notification = described_class.notification('test/method', { param1: 'value1' })
      
      expect(notification[:jsonrpc]).to eq('2.0')
      expect(notification[:method]).to eq('test/method')
      expect(notification[:params]).to eq({ param1: 'value1' })
      expect(notification[:id]).to be_nil
    end
    
    it 'omits params if not provided' do
      notification = described_class.notification('test/method')
      
      expect(notification[:jsonrpc]).to eq('2.0')
      expect(notification[:method]).to eq('test/method')
      expect(notification[:params]).to be_nil
      expect(notification[:id]).to be_nil
    end
  end
  
  describe '.response' do
    it 'creates a valid JSON-RPC 2.0 response' do
      id = SecureRandom.uuid
      response = described_class.response({ result: 'value' }, id)
      
      expect(response[:jsonrpc]).to eq('2.0')
      expect(response[:result]).to eq({ result: 'value' })
      expect(response[:id]).to eq(id)
      expect(response[:error]).to be_nil
    end
  end
  
  describe '.error' do
    it 'creates a valid JSON-RPC 2.0 error response' do
      id = SecureRandom.uuid
      error = { code: -32600, message: 'Invalid Request' }
      response = described_class.error(error, id)
      
      expect(response[:jsonrpc]).to eq('2.0')
      expect(response[:error]).to eq(error)
      expect(response[:id]).to eq(id)
      expect(response[:result]).to be_nil
    end
    
    it 'handles nil id for parse errors' do
      error = { code: -32700, message: 'Parse error' }
      response = described_class.error(error, nil)
      
      expect(response[:jsonrpc]).to eq('2.0')
      expect(response[:error]).to eq(error)
      expect(response[:id]).to be_nil
      expect(response[:result]).to be_nil
    end
  end
  
  describe '.is_request?' do
    it 'returns true for valid requests' do
      request = described_class.request('test/method')
      expect(described_class.is_request?(request)).to be(true)
    end
    
    it 'returns false for notifications' do
      notification = described_class.notification('test/method')
      expect(described_class.is_request?(notification)).to be(false)
    end
    
    it 'returns false for responses' do
      response = described_class.response({}, 'id')
      expect(described_class.is_request?(response)).to be(false)
    end
    
    it 'returns false for error responses' do
      error = described_class.error({ code: -32600, message: 'Invalid Request' }, 'id')
      expect(described_class.is_request?(error)).to be(false)
    end
  end
  
  describe '.is_notification?' do
    it 'returns true for valid notifications' do
      notification = described_class.notification('test/method')
      expect(described_class.is_notification?(notification)).to be(true)
    end
    
    it 'returns false for requests' do
      request = described_class.request('test/method')
      expect(described_class.is_notification?(request)).to be(false)
    end
    
    it 'returns false for responses' do
      response = described_class.response({}, 'id')
      expect(described_class.is_notification?(response)).to be(false)
    end
  end
  
  describe '.is_response?' do
    it 'returns true for valid responses' do
      response = described_class.response({}, 'id')
      expect(described_class.is_response?(response)).to be(true)
    end
    
    it 'returns false for requests' do
      request = described_class.request('test/method')
      expect(described_class.is_response?(request)).to be(false)
    end
    
    it 'returns false for notifications' do
      notification = described_class.notification('test/method')
      expect(described_class.is_response?(notification)).to be(false)
    end
  end
  
  describe '.is_error?' do
    it 'returns true for valid error responses' do
      error = described_class.error({ code: -32600, message: 'Invalid Request' }, 'id')
      expect(described_class.is_error?(error)).to be(true)
    end
    
    it 'returns false for success responses' do
      response = described_class.response({}, 'id')
      expect(described_class.is_error?(response)).to be(false)
    end
    
    it 'returns false for requests' do
      request = described_class.request('test/method')
      expect(described_class.is_error?(request)).to be(false)
    end
  end
  
  describe '.parse' do
    it 'parses valid JSON-RPC 2.0 messages' do
      json = '{"jsonrpc":"2.0","method":"test/method","params":{"param1":"value1"},"id":"123"}'
      message = described_class.parse(json)
      
      expect(message[:jsonrpc]).to eq('2.0')
      expect(message[:method]).to eq('test/method')
      expect(message[:params]).to eq({ param1: 'value1' })
      expect(message[:id]).to eq('123')
    end
    
    it 'raises an error for invalid JSON' do
      expect {
        described_class.parse('{invalid json}')
      }.to raise_error(MCP::Errors::ParseError)
    end
    
    it 'raises an error for invalid JSON-RPC' do
      expect {
        described_class.parse('{"foo":"bar"}')
      }.to raise_error(MCP::Errors::InvalidRequestError)
    end
  end
end