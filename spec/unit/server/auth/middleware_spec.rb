# frozen_string_literal: true

RSpec.describe MCP::Server::Auth::Middleware do
  let(:app) { ->(env) { [200, {}, ['Success']] } }
  let(:auth_provider) { double('OAuth Provider') }
  let(:permissions) { double('Permissions Manager') }
  let(:middleware) { described_class.new(app, auth_provider, permissions) }
  
  describe '#initialize' do
    it 'sets app, auth_provider, and permissions' do
      expect(middleware.instance_variable_get(:@app)).to eq(app)
      expect(middleware.instance_variable_get(:@auth_provider)).to eq(auth_provider)
      expect(middleware.instance_variable_get(:@permissions)).to eq(permissions)
    end
  end
  
  describe '#call' do
    let(:env) { { 'HTTP_AUTHORIZATION' => 'Bearer token123' } }
    
    context 'with valid token' do
      let(:token_payload) { { 'sub' => 'user123', 'scopes' => ['tools:read'] } }
      
      before do
        allow(auth_provider).to receive(:verify_jwt).with('token123').and_return(token_payload)
        allow(permissions).to receive(:check_permission).and_return(true)
      end
      
      it 'verifies the token and calls the next middleware' do
        expect(auth_provider).to receive(:verify_jwt).with('token123')
        expect(app).to receive(:call).with(hash_including(env))
        
        middleware.call(env)
      end
      
      it 'adds the token payload to the environment' do
        response = middleware.call(env)
        
        expect(response).to eq([200, {}, ['Success']])
        expect(env['mcp.auth.payload']).to eq(token_payload)
      end
    end
    
    context 'with invalid token' do
      before do
        allow(auth_provider).to receive(:verify_jwt).with('token123').and_return(nil)
      end
      
      it 'returns 401 Unauthorized' do
        response = middleware.call(env)
        
        expect(response[0]).to eq(401) # Status code
        expect(response[1]).to include('Content-Type' => 'application/json')
        expect(response[2][0]).to include('error' => 'Invalid token')
      end
    end
    
    context 'without token' do
      let(:env) { {} }
      
      it 'returns 401 Unauthorized if auth is enabled' do
        response = middleware.call(env)
        
        expect(response[0]).to eq(401) # Status code
        expect(response[1]).to include('Content-Type' => 'application/json')
        expect(response[2][0]).to include('error' => 'Unauthorized')
      end
      
      it 'skips auth if auth_provider is nil' do
        middleware = described_class.new(app, nil, permissions)
        
        expect(app).to receive(:call).with(env)
        middleware.call(env)
      end
    end
    
    context 'with JSON-RPC request' do
      let(:json_rpc_request) do
        '{"jsonrpc":"2.0","method":"tools/list","id":"123"}'
      end
      
      let(:env) do
        {
          'HTTP_AUTHORIZATION' => 'Bearer token123',
          'CONTENT_TYPE' => 'application/json',
          'REQUEST_METHOD' => 'POST',
          'rack.input' => StringIO.new(json_rpc_request)
        }
      end
      
      let(:token_payload) { { 'sub' => 'user123', 'scopes' => ['tools:read'] } }
      
      before do
        allow(auth_provider).to receive(:verify_jwt).with('token123').and_return(token_payload)
      end
      
      it 'checks permission for the JSON-RPC method' do
        expect(permissions).to receive(:check_permission).with(token_payload, 'tools/list').and_return(true)
        
        middleware.call(env)
        
        # Verify rack.input was reset for the next middleware
        expect(env['rack.input'].read).to eq(json_rpc_request)
      end
      
      it 'returns 403 Forbidden if permission check fails' do
        expect(permissions).to receive(:check_permission).with(token_payload, 'tools/list').and_return(false)
        
        response = middleware.call(env)
        
        expect(response[0]).to eq(403) # Status code
        expect(response[1]).to include('Content-Type' => 'application/json')
        expect(response[2][0]).to include('error' => 'Forbidden')
        
        # Verify rack.input was reset for the next middleware
        expect(env['rack.input'].read).to eq(json_rpc_request)
      end
    end
  end
  
  describe '#extract_token' do
    it 'extracts token from Authorization header' do
      env = { 'HTTP_AUTHORIZATION' => 'Bearer token123' }
      token = middleware.send(:extract_token, env)
      expect(token).to eq('token123')
    end
    
    it 'returns nil if Authorization header is missing' do
      env = {}
      token = middleware.send(:extract_token, env)
      expect(token).to be_nil
    end
    
    it 'returns nil if Authorization header does not start with Bearer' do
      env = { 'HTTP_AUTHORIZATION' => 'Basic dXNlcjpwYXNz' }
      token = middleware.send(:extract_token, env)
      expect(token).to be_nil
    end
  end
  
  describe '#is_jsonrpc_request?' do
    it 'returns true for valid JSON-RPC requests' do
      env = {
        'CONTENT_TYPE' => 'application/json',
        'REQUEST_METHOD' => 'POST',
        'rack.input' => StringIO.new('{"jsonrpc":"2.0","method":"test","id":"123"}')
      }
      
      result = middleware.send(:is_jsonrpc_request?, env)
      expect(result).to be(true)
    end
    
    it 'returns false if content type is not application/json' do
      env = {
        'CONTENT_TYPE' => 'text/plain',
        'REQUEST_METHOD' => 'POST',
        'rack.input' => StringIO.new('{"jsonrpc":"2.0","method":"test","id":"123"}')
      }
      
      result = middleware.send(:is_jsonrpc_request?, env)
      expect(result).to be(false)
    end
    
    it 'returns false if request method is not POST' do
      env = {
        'CONTENT_TYPE' => 'application/json',
        'REQUEST_METHOD' => 'GET',
        'rack.input' => StringIO.new('{"jsonrpc":"2.0","method":"test","id":"123"}')
      }
      
      result = middleware.send(:is_jsonrpc_request?, env)
      expect(result).to be(false)
    end
    
    it 'returns false if body is not valid JSON' do
      env = {
        'CONTENT_TYPE' => 'application/json',
        'REQUEST_METHOD' => 'POST',
        'rack.input' => StringIO.new('invalid json')
      }
      
      result = middleware.send(:is_jsonrpc_request?, env)
      expect(result).to be(false)
    end
    
    it 'returns false if JSON does not have jsonrpc and method fields' do
      env = {
        'CONTENT_TYPE' => 'application/json',
        'REQUEST_METHOD' => 'POST',
        'rack.input' => StringIO.new('{"foo":"bar"}')
      }
      
      result = middleware.send(:is_jsonrpc_request?, env)
      expect(result).to be(false)
    end
  end
  
  describe '#extract_jsonrpc_method' do
    it 'extracts method from JSON-RPC request' do
      env = {
        'rack.input' => StringIO.new('{"jsonrpc":"2.0","method":"tools/list","id":"123"}')
      }
      
      method = middleware.send(:extract_jsonrpc_method, env)
      expect(method).to eq('tools/list')
    end
    
    it 'returns nil if body is not valid JSON' do
      env = {
        'rack.input' => StringIO.new('invalid json')
      }
      
      method = middleware.send(:extract_jsonrpc_method, env)
      expect(method).to be_nil
    end
    
    it 'returns nil if JSON does not have method field' do
      env = {
        'rack.input' => StringIO.new('{"jsonrpc":"2.0","id":"123"}')
      }
      
      method = middleware.send(:extract_jsonrpc_method, env)
      expect(method).to be_nil
    end
  end
end