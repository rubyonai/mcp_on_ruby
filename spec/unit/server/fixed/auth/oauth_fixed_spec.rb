# frozen_string_literal: true

require 'jwt'
require 'oauth2'

RSpec.describe "MCP::Server::Auth::OAuth" do
  # Use the fixed implementation
  let(:oauth_class) { MCP::Server::Auth::OAuth }
  let(:options) do
    {
      client_id: 'test_client',
      client_secret: 'test_secret',
      token_expiry: 3600,
      jwt_secret: 'test_jwt_secret',
      issuer: 'test_issuer',
      scopes: ['tools:read', 'tools:call']
    }
  end
  
  let(:oauth_provider) { oauth_class.new(options) }
  
  describe '#initialize' do
    it 'sets provider properties' do
      expect(oauth_provider.client_id).to eq('test_client')
      expect(oauth_provider.client_secret).to eq('test_secret')
      expect(oauth_provider.token_expiry).to eq(3600)
      expect(oauth_provider.jwt_secret).to eq('test_jwt_secret')
      expect(oauth_provider.issuer).to eq('test_issuer')
      expect(oauth_provider.scopes).to contain_exactly('tools:read', 'tools:call')
    end
    
    it 'uses default values if not provided' do
      provider = oauth_class.new(client_id: 'client', client_secret: 'secret')
      
      expect(provider.token_expiry).to eq(3600)
      expect(provider.jwt_secret).to be_a(String)
      expect(provider.issuer).to eq('mcp_server')
      expect(provider.scopes).to eq(['mcp'])
    end
  end
  
  describe '#create_jwt' do
    # Create a custom token class for testing
    class TestAccessToken
      attr_reader :params
      
      def initialize(params)
        @params = params
      end
    end
    
    it 'creates a valid JWT with user details' do
      token = TestAccessToken.new({
        'user_id' => '123',
        'scope' => 'tools:read tools:call'
      })
      
      jwt = oauth_provider.create_jwt(token)
      
      # Decode and verify the JWT
      decoded = JWT.decode(jwt, 'test_jwt_secret', true, { algorithm: 'HS256' })
      payload = decoded.first
      
      expect(payload['sub']).to eq('123')
      expect(payload['iss']).to eq('test_issuer')
      expect(payload['scopes']).to contain_exactly('tools:read', 'tools:call')
      expect(payload['exp']).to be > Time.now.to_i
      expect(payload['iat']).to be <= Time.now.to_i
    end
    
    it 'uses fallback sub from params' do
      token = TestAccessToken.new({
        'sub' => 'user_123',
        'scope' => 'tools:read'
      })
      
      jwt = oauth_provider.create_jwt(token)
      decoded = JWT.decode(jwt, 'test_jwt_secret', true, { algorithm: 'HS256' })
      
      expect(decoded.first['sub']).to eq('user_123')
    end
    
    it 'uses default scopes if not provided in token' do
      token = TestAccessToken.new({
        'user_id' => '123'
      })
      
      jwt = oauth_provider.create_jwt(token)
      decoded = JWT.decode(jwt, 'test_jwt_secret', true, { algorithm: 'HS256' })
      
      expect(decoded.first['scopes']).to contain_exactly('tools:read', 'tools:call')
    end
  end
  
  describe '#verify_jwt' do
    let(:valid_payload) do
      {
        'sub' => 'user_123',
        'exp' => Time.now.to_i + 3600,
        'iat' => Time.now.to_i,
        'iss' => 'test_issuer',
        'scopes' => ['tools:read', 'tools:call']
      }
    end
    
    let(:expired_payload) do
      {
        'sub' => 'user_123',
        'exp' => Time.now.to_i - 3600,
        'iat' => Time.now.to_i - 7200,
        'iss' => 'test_issuer',
        'scopes' => ['tools:read', 'tools:call']
      }
    end
    
    it 'verifies and returns payload for a valid token' do
      token = JWT.encode(valid_payload, 'test_jwt_secret', 'HS256')
      
      result = oauth_provider.verify_jwt(token)
      expect(result).to be_a(Hash)
      expect(result['sub']).to eq('user_123')
      expect(result['scopes']).to contain_exactly('tools:read', 'tools:call')
    end
    
    it 'returns nil for an expired token' do
      token = JWT.encode(expired_payload, 'test_jwt_secret', 'HS256')
      
      result = oauth_provider.verify_jwt(token)
      expect(result).to be_nil
    end
    
    it 'returns nil for an invalid token' do
      token = 'invalid_token'
      
      result = oauth_provider.verify_jwt(token)
      expect(result).to be_nil
    end
    
    it 'returns nil for a token with invalid signature' do
      token = JWT.encode(valid_payload, 'wrong_secret', 'HS256')
      
      result = oauth_provider.verify_jwt(token)
      expect(result).to be_nil
    end
  end
  
  describe '#authenticate_client' do
    it 'returns true for valid client credentials' do
      client_id = 'test_client'
      client_secret = 'test_secret'
      
      result = oauth_provider.authenticate_client(client_id, client_secret)
      expect(result).to be(true)
    end
    
    it 'returns false for invalid client credentials' do
      client_id = 'test_client'
      client_secret = 'wrong_secret'
      
      result = oauth_provider.authenticate_client(client_id, client_secret)
      expect(result).to be(false)
      
      client_id = 'wrong_client'
      client_secret = 'test_secret'
      
      result = oauth_provider.authenticate_client(client_id, client_secret)
      expect(result).to be(false)
    end
  end
  
  describe '#create_token' do
    it 'creates an OAuth token with provided parameters' do
      params = {
        'user_id' => '123',
        'scope' => 'tools:read',
        'client_id' => 'test_client'
      }
      
      token = oauth_provider.create_token(params)
      
      expect(token).to be_a(OAuth2::AccessToken)
      expect(token.token).to be_a(String)
      expect(token.refresh_token).to be_a(String)
      expect(token.expires_in).to eq(3600)
      
      # Test parameter preservation
      expect(token.params['user_id']).to eq('123')
      expect(token.params['scope']).to eq('tools:read')
    end
    
    it 'includes default scopes if not provided' do
      params = {
        'user_id' => '123',
        'client_id' => 'test_client'
      }
      
      token = oauth_provider.create_token(params)
      
      # Check that default scope is set
      expect(token.params['scope']).to eq('tools:read tools:call')
    end
  end
  
  describe '#verify_scope' do
    it 'returns true if token has the required scope' do
      token_payload = {
        'scopes' => ['tools:read', 'tools:call']
      }
      
      expect(oauth_provider.verify_scope(token_payload, 'tools:read')).to be(true)
      expect(oauth_provider.verify_scope(token_payload, 'tools:call')).to be(true)
    end
    
    it 'returns false if token does not have the required scope' do
      token_payload = {
        'scopes' => ['tools:read']
      }
      
      expect(oauth_provider.verify_scope(token_payload, 'tools:call')).to be(false)
      expect(oauth_provider.verify_scope(token_payload, 'resources:read')).to be(false)
    end
    
    it 'handles nil token payload' do
      expect(oauth_provider.verify_scope(nil, 'tools:read')).to be(false)
    end
    
    it 'handles nil or empty scopes in token' do
      expect(oauth_provider.verify_scope({}, 'tools:read')).to be(false)
      expect(oauth_provider.verify_scope({ 'scopes' => nil }, 'tools:read')).to be(false)
      expect(oauth_provider.verify_scope({ 'scopes' => [] }, 'tools:read')).to be(false)
    end
  end
end