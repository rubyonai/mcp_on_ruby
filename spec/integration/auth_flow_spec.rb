# frozen_string_literal: true

require 'jwt'
require 'oauth2'
require 'rack/test'

RSpec.describe "Authentication integration" do
  include Rack::Test::Methods
  
  let(:oauth_options) do
    {
      client_id: 'test_client',
      client_secret: 'test_secret',
      site: 'http://localhost:3000',
      authorize_url: '/oauth/authorize',
      token_url: '/oauth/token',
      scopes: ['tools:read', 'tools:call'],
      auto_refresh: true
    }
  end
  
  let(:jwt_secret) { 'test_jwt_secret' }
  
  let(:valid_token) do
    payload = {
      sub: 'user_123',
      exp: Time.now.to_i + 3600,
      iat: Time.now.to_i,
      iss: 'test_issuer',
      scopes: ['tools:read', 'tools:call']
    }
    
    JWT.encode(payload, jwt_secret, 'HS256')
  end
  
  let(:expired_token) do
    payload = {
      sub: 'user_123',
      exp: Time.now.to_i - 3600,
      iat: Time.now.to_i - 7200,
      iss: 'test_issuer',
      scopes: ['tools:read', 'tools:call']
    }
    
    JWT.encode(payload, jwt_secret, 'HS256')
  end
  
  let(:limited_token) do
    payload = {
      sub: 'user_123',
      exp: Time.now.to_i + 3600,
      iat: Time.now.to_i,
      iss: 'test_issuer',
      scopes: ['tools:read'] # Only read access, no call access
    }
    
    JWT.encode(payload, jwt_secret, 'HS256')
  end
  
  let(:client) { MCP::Client::Client.new(url: 'http://localhost:3000/mcp') }
  
  # Since we can't easily set up a real OAuth server in tests,
  # we'll mock the authentication components
  
  describe "client authentication" do
    # Mock the OAuth2 client and token
    let(:oauth_client) { instance_double(OAuth2::Client) }
    let(:auth_code) { instance_double(OAuth2::Strategy::AuthCode) }
    let(:token) do
      instance_double(
        OAuth2::AccessToken,
        token: valid_token,
        refresh_token: 'refresh_token',
        expires_in: 3600,
        params: {
          'user_id' => 'user_123',
          'scope' => 'tools:read tools:call'
        },
        expired?: false
      )
    end
    
    before do
      # Mock OAuth2 client
      allow(OAuth2::Client).to receive(:new).and_return(oauth_client)
      allow(oauth_client).to receive(:auth_code).and_return(auth_code)
      
      # Mock auth code authorization URL
      allow(auth_code).to receive(:authorize_url).and_return(
        'http://localhost:3000/oauth/authorize?client_id=test_client&response_type=code&redirect_uri=http%3A%2F%2Flocalhost%3A8000%2Fcallback&scope=tools%3Aread+tools%3Acall&state=test_state'
      )
      
      # Mock token exchange
      allow(auth_code).to receive(:get_token).and_return(token)
      
      # Mock token refresh
      allow(token).to receive(:refresh!).and_return(token)
      
      # Mock connection
      allow(MCP::Protocol).to receive(:connect).and_return(
        double(
          'Connection',
          initialize_connection: {
            serverInfo: {
              name: 'Test Server',
              version: '1.0.0'
            },
            protocolVersion: MCP::PROTOCOL_VERSION,
            capabilities: {}
          },
          send_request: { result: 'success' }
        )
      )
    end
    
    it "gets an authorization URL" do
      client.set_oauth_credentials(oauth_options)
      
      url = client.authorization_url('test_state')
      
      expect(url).to include('/oauth/authorize')
      expect(url).to include('client_id=test_client')
      expect(url).to include('state=test_state')
    end
    
    it "exchanges an authorization code for a token" do
      client.set_oauth_credentials(oauth_options)
      
      token = client.exchange_code('test_code')
      
      expect(token.token).to eq(valid_token)
      expect(client.authenticated?).to be(true)
    end
    
    it "sets access token directly" do
      client.set_oauth_credentials(oauth_options)
      client.set_access_token(valid_token)
      
      expect(client.authenticated?).to be(true)
      expect(client.scopes).to include('tools:read', 'tools:call')
    end
    
    it "refreshes an expired token" do
      # Set up an expired token
      expired = instance_double(
        OAuth2::AccessToken,
        token: expired_token,
        refresh_token: 'refresh_token',
        expires_in: -1,
        params: {
          'user_id' => 'user_123',
          'scope' => 'tools:read tools:call'
        },
        expired?: true
      )
      
      # It should refresh to a valid token
      allow(expired).to receive(:refresh!).and_return(token)
      
      client.set_oauth_credentials(oauth_options)
      client.instance_variable_set(:@access_token, expired)
      
      # Refresh the token
      refreshed = client.refresh_token
      
      expect(refreshed.token).to eq(valid_token)
      expect(refreshed.expired?).to be(false)
    end
  end
  
  describe "authenticated requests" do
    # Mock the transport and connection
    let(:transport) { instance_double(MCP::Protocol::Transport::HTTP) }
    let(:connection) do
      double(
        'Connection',
        initialize_connection: {
          serverInfo: {
            name: 'Test Server',
            version: '1.0.0'
          },
          protocolVersion: MCP::PROTOCOL_VERSION,
          capabilities: {}
        },
        send_request: { result: 'success' }
      )
    end
    
    before do
      # Set up the client with mocked transport
      allow(MCP::Protocol).to receive(:create_transport).and_return(transport)
      allow(transport).to receive(:connect).and_return(connection)
      allow(transport).to receive(:headers).and_return({})
      allow(transport).to receive(:headers=)
      allow(transport).to receive(:set_auth_token)
      allow(transport).to receive(:on_event)
      
      # Set up OAuth client with a valid token
      client.set_oauth_credentials(oauth_options)
      client.set_access_token(valid_token)
    end
    
    it "adds Authorization header to requests" do
      expect(transport).to receive(:set_auth_token).with(valid_token)
      
      # Connect to ensure headers are applied
      client.connect
    end
    
    it "handles authentication errors" do
      # Mock a 401 Unauthorized response
      error_response = {
        jsonrpc: '2.0',
        error: {
          code: -32000,
          message: 'authentication required'
        },
        id: '123'
      }
      
      # Connection should raise an auth error
      allow(connection).to receive(:send_request).and_raise(
        MCP::Errors::AuthenticationError.new('Authentication required')
      )
      
      client.connect
      
      # Should raise auth error when calling methods
      expect {
        client.call_method('tools/list')
      }.to raise_error(MCP::Errors::AuthenticationError)
    end
    
    it "handles token refresh when token expires" do
      # Set up token refresh handler
      refresh_handler = nil
      allow(transport).to receive(:on_event) do |event, &block|
        if event == 'auth.refresh'
          refresh_handler = block
        end
      end
      
      # Set up a token that will be refreshed
      token = instance_double(
        OAuth2::AccessToken,
        token: valid_token,
        refresh_token: 'refresh_token',
        params: {
          'user_id' => 'user_123',
          'scope' => 'tools:read tools:call'
        }
      )
      
      # Refreshed token
      refreshed_token = instance_double(
        OAuth2::AccessToken,
        token: 'new_token',
        refresh_token: 'new_refresh_token',
        params: {
          'user_id' => 'user_123',
          'scope' => 'tools:read tools:call'
        }
      )
      
      allow(token).to receive(:refresh!).and_return(refreshed_token)
      
      # Set the token
      client.instance_variable_set(:@access_token, token)
      
      # Connect the client to register refresh handler
      client.connect
      
      # Mock token expiration by triggering the refresh handler
      refresh_handler.call
      
      # Verify token was refreshed
      expect(client.instance_variable_get(:@access_token)).to eq(refreshed_token)
      expect(transport).to have_received(:set_auth_token).with('new_token')
    end
  end
  
  describe "server authentication middleware" do
    # Create a simple Rack app with auth middleware for testing
    let(:oauth_provider) do
      MCP::Server::Auth::OAuth.new(
        client_id: 'test_client',
        client_secret: 'test_secret',
        jwt_secret: jwt_secret,
        issuer: 'test_issuer'
      )
    end
    
    let(:permissions) do
      permissions = MCP::Server::Auth::Permissions.new
      permissions.add_method('tools/list', ['tools:read'])
      permissions.add_method('tools/call', ['tools:call'])
      permissions
    end
    
    let(:app) do
      test_app = lambda do |env|
        # Get the JSON-RPC request from the environment
        request_body = env['rack.input'].read
        env['rack.input'].rewind
        
        begin
          request = JSON.parse(request_body)
          
          # Handle different methods
          case request['method']
          when 'tools/list'
            result = [{ name: 'test.tool', schema: {} }]
          when 'tools/call'
            result = { success: true }
          else
            result = { error: 'Method not found' }
          end
          
          # Return a JSON-RPC response
          [
            200,
            { 'Content-Type' => 'application/json' },
            [
              {
                jsonrpc: '2.0',
                result: result,
                id: request['id']
              }.to_json
            ]
          ]
        rescue => e
          [
            400,
            { 'Content-Type' => 'application/json' },
            [
              {
                jsonrpc: '2.0',
                error: {
                  code: -32700,
                  message: e.message
                },
                id: nil
              }.to_json
            ]
          ]
        end
      end
      
      # Wrap the test app with the auth middleware
      middleware = MCP::Server::Auth::Middleware.new(test_app, oauth_provider, permissions)
      
      # Return the middleware as the app
      middleware
    end
    
    def app
      # Required for Rack::Test
      @app
    end
    
    before do
      @app = app
    end
    
    it "allows requests with valid token and permissions" do
      # Create a valid JSON-RPC request for tools/list
      request = {
        jsonrpc: '2.0',
        method: 'tools/list',
        id: '123'
      }
      
      # Make a request with a valid token
      header 'Authorization', "Bearer #{valid_token}"
      header 'Content-Type', 'application/json'
      post '/', request.to_json
      
      # Verify the response
      expect(last_response.status).to eq(200)
      
      response = JSON.parse(last_response.body)
      expect(response['result']).to be_an(Array)
    end
    
    it "rejects requests without a token" do
      # Create a valid JSON-RPC request for tools/list
      request = {
        jsonrpc: '2.0',
        method: 'tools/list',
        id: '123'
      }
      
      # Make a request without a token
      header 'Content-Type', 'application/json'
      post '/', request.to_json
      
      # Verify the response
      expect(last_response.status).to eq(401)
      
      response = JSON.parse(last_response.body)
      expect(response['error']).to eq('Unauthorized')
    end
    
    it "rejects requests with an expired token" do
      # Create a valid JSON-RPC request for tools/list
      request = {
        jsonrpc: '2.0',
        method: 'tools/list',
        id: '123'
      }
      
      # Make a request with an expired token
      header 'Authorization', "Bearer #{expired_token}"
      header 'Content-Type', 'application/json'
      post '/', request.to_json
      
      # Verify the response
      expect(last_response.status).to eq(401)
      
      response = JSON.parse(last_response.body)
      expect(response['error']).to eq('Invalid token')
    end
    
    it "rejects requests without required permissions" do
      # Create a JSON-RPC request for tools/call (requires tools:call scope)
      request = {
        jsonrpc: '2.0',
        method: 'tools/call',
        id: '123'
      }
      
      # Make a request with a token that only has tools:read scope
      header 'Authorization', "Bearer #{limited_token}"
      header 'Content-Type', 'application/json'
      post '/', request.to_json
      
      # Verify the response
      expect(last_response.status).to eq(403)
      
      response = JSON.parse(last_response.body)
      expect(response['error']).to eq('Forbidden')
    end
    
    it "allows requests with the proper permissions" do
      # Create a JSON-RPC request for tools/list (requires tools:read scope)
      request = {
        jsonrpc: '2.0',
        method: 'tools/list',
        id: '123'
      }
      
      # Make a request with a token that has tools:read scope
      header 'Authorization', "Bearer #{limited_token}"
      header 'Content-Type', 'application/json'
      post '/', request.to_json
      
      # Verify the response
      expect(last_response.status).to eq(200)
      
      response = JSON.parse(last_response.body)
      expect(response['result']).to be_an(Array)
    end
  end
end