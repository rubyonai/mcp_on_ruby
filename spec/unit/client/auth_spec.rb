# frozen_string_literal: true

require 'oauth2'

RSpec.describe MCP::Client::Auth do
  let(:client) { Object.new.extend(described_class) }
  let(:oauth_client) { double('OAuth2::Client') }
  let(:transport) { double('Transport', headers: {}) }
  
  before do
    client.instance_variable_set(:@logger, Logger.new(nil))
    client.instance_variable_set(:@transport, transport)
    
    allow(OAuth2::Client).to receive(:new).and_return(oauth_client)
  end
  
  describe '#set_oauth_credentials' do
    let(:options) do
      {
        client_id: 'test_client',
        client_secret: 'test_secret',
        site: 'https://auth.example.com',
        authorize_url: '/oauth/authorize',
        token_url: '/oauth/token',
        scopes: ['tools:read', 'tools:call'],
        auto_refresh: true
      }
    end
    
    it 'creates an OAuth client with the provided options' do
      expect(OAuth2::Client).to receive(:new).with(
        'test_client',
        'test_secret',
        site: 'https://auth.example.com',
        authorize_url: '/oauth/authorize',
        token_url: '/oauth/token'
      )
      
      client.set_oauth_credentials(options)
      
      expect(client.instance_variable_get(:@oauth_options)).to eq(options)
      expect(client.instance_variable_get(:@oauth_client)).to eq(oauth_client)
    end
    
    it 'sets up token refresh if auto_refresh is enabled' do
      expect(client).to receive(:setup_token_refresh)
      
      client.set_oauth_credentials(options)
    end
    
    it 'does not set up token refresh if auto_refresh is disabled' do
      options[:auto_refresh] = false
      
      expect(client).not_to receive(:setup_token_refresh)
      
      client.set_oauth_credentials(options)
    end
  end
  
  describe '#authorization_url' do
    let(:auth_code) { double('OAuth2::Strategy::AuthCode') }
    
    before do
      client.instance_variable_set(:@oauth_client, oauth_client)
      client.instance_variable_set(:@oauth_options, {
        redirect_uri: 'https://example.com/callback',
        scopes: ['tools:read', 'tools:call']
      })
      
      allow(oauth_client).to receive(:auth_code).and_return(auth_code)
    end
    
    it 'returns an authorization URL with the provided state' do
      expect(auth_code).to receive(:authorize_url).with(
        redirect_uri: 'https://example.com/callback',
        scope: ['tools:read', 'tools:call'],
        state: 'test_state'
      ).and_return('https://auth.example.com/oauth/authorize?...')
      
      url = client.authorization_url('test_state')
      expect(url).to eq('https://auth.example.com/oauth/authorize?...')
    end
    
    it 'uses provided redirect_uri if specified' do
      expect(auth_code).to receive(:authorize_url).with(
        redirect_uri: 'https://other.example.com/callback',
        scope: ['tools:read', 'tools:call'],
        state: 'test_state'
      )
      
      client.authorization_url('test_state', 'https://other.example.com/callback')
    end
    
    it 'uses provided scopes if specified' do
      expect(auth_code).to receive(:authorize_url).with(
        redirect_uri: 'https://example.com/callback',
        scope: ['resources:read'],
        state: 'test_state'
      )
      
      client.authorization_url('test_state', nil, ['resources:read'])
    end
    
    it 'raises an error if no OAuth client is available' do
      client.instance_variable_set(:@oauth_client, nil)
      
      expect {
        client.authorization_url('test_state')
      }.to raise_error(MCP::Errors::AuthenticationError)
    end
  end
  
  describe '#exchange_code' do
    let(:auth_code) { double('OAuth2::Strategy::AuthCode') }
    let(:token) { double('OAuth2::AccessToken', token: 'access_token') }
    
    before do
      client.instance_variable_set(:@oauth_client, oauth_client)
      client.instance_variable_set(:@oauth_options, {
        redirect_uri: 'https://example.com/callback'
      })
      
      allow(oauth_client).to receive(:auth_code).and_return(auth_code)
      allow(auth_code).to receive(:get_token).and_return(token)
    end
    
    it 'exchanges the code for a token' do
      expect(auth_code).to receive(:get_token).with(
        'test_code',
        redirect_uri: 'https://example.com/callback'
      ).and_return(token)
      
      result = client.exchange_code('test_code')
      expect(result).to eq(token)
    end
    
    it 'uses provided redirect_uri if specified' do
      expect(auth_code).to receive(:get_token).with(
        'test_code',
        redirect_uri: 'https://other.example.com/callback'
      ).and_return(token)
      
      client.exchange_code('test_code', 'https://other.example.com/callback')
    end
    
    it 'stores the token and updates the transport auth header' do
      client.exchange_code('test_code')
      
      expect(client.instance_variable_get(:@access_token)).to eq(token)
      expect(client).to have_received(:update_transport_auth).with(token)
    end
    
    it 'raises an error if no OAuth client is available' do
      client.instance_variable_set(:@oauth_client, nil)
      
      expect {
        client.exchange_code('test_code')
      }.to raise_error(MCP::Errors::AuthenticationError)
    end
  end
  
  describe '#refresh_token' do
    let(:token) { double('OAuth2::AccessToken', refresh_token: 'refresh_token', token: 'new_token') }
    let(:refreshed_token) { double('OAuth2::AccessToken', token: 'refreshed_token') }
    
    before do
      client.instance_variable_set(:@oauth_client, oauth_client)
      client.instance_variable_set(:@access_token, token)
      
      allow(token).to receive(:refresh!).and_return(refreshed_token)
    end
    
    it 'refreshes the token' do
      expect(token).to receive(:refresh!).and_return(refreshed_token)
      
      result = client.refresh_token
      expect(result).to eq(refreshed_token)
    end
    
    it 'stores the refreshed token and updates the transport auth header' do
      client.refresh_token
      
      expect(client.instance_variable_get(:@access_token)).to eq(refreshed_token)
      expect(client).to have_received(:update_transport_auth).with(refreshed_token)
    end
    
    it 'raises an error if no access token is available' do
      client.instance_variable_set(:@access_token, nil)
      
      expect {
        client.refresh_token
      }.to raise_error(MCP::Errors::AuthenticationError)
    end
    
    it 'raises an error if the token has no refresh token' do
      allow(token).to receive(:refresh_token).and_return(nil)
      
      expect {
        client.refresh_token
      }.to raise_error(MCP::Errors::AuthenticationError)
    end
    
    it 'raises an error if no OAuth client is available' do
      client.instance_variable_set(:@oauth_client, nil)
      
      expect {
        client.refresh_token
      }.to raise_error(MCP::Errors::AuthenticationError)
    end
  end
  
  describe '#set_access_token' do
    let(:token) { double('OAuth2::AccessToken', token: 'access_token') }
    
    before do
      client.instance_variable_set(:@oauth_client, oauth_client)
    end
    
    it 'sets a string token' do
      allow(OAuth2::AccessToken).to receive(:new).with(oauth_client, 'test_token').and_return(token)
      
      client.set_access_token('test_token')
      
      expect(client.instance_variable_get(:@access_token)).to eq(token)
      expect(client).to have_received(:update_transport_auth).with(token)
    end
    
    it 'sets an OAuth2::AccessToken object' do
      client.set_access_token(token)
      
      expect(client.instance_variable_get(:@access_token)).to eq(token)
      expect(client).to have_received(:update_transport_auth).with(token)
    end
  end
  
  describe '#access_token' do
    let(:token) { double('OAuth2::AccessToken') }
    
    it 'returns the current access token' do
      client.instance_variable_set(:@access_token, token)
      
      expect(client.access_token).to eq(token)
    end
    
    it 'returns nil if no access token is set' do
      client.instance_variable_set(:@access_token, nil)
      
      expect(client.access_token).to be_nil
    end
  end
  
  describe '#authenticated?' do
    let(:token) { double('OAuth2::AccessToken') }
    
    it 'returns true if token exists and is not expired' do
      allow(token).to receive(:expired?).and_return(false)
      client.instance_variable_set(:@access_token, token)
      
      expect(client.authenticated?).to be(true)
    end
    
    it 'returns false if token does not exist' do
      client.instance_variable_set(:@access_token, nil)
      
      expect(client.authenticated?).to be(false)
    end
    
    it 'returns false if token is expired' do
      allow(token).to receive(:expired?).and_return(true)
      client.instance_variable_set(:@access_token, token)
      
      expect(client.authenticated?).to be(false)
    end
  end
  
  describe '#scopes' do
    let(:token) { double('OAuth2::AccessToken', params: { 'scope' => 'tools:read tools:call' }) }
    
    it 'returns token scopes' do
      client.instance_variable_set(:@access_token, token)
      
      expect(client.scopes).to contain_exactly('tools:read', 'tools:call')
    end
    
    it 'returns empty array if token has no scopes' do
      token = double('OAuth2::AccessToken', params: {})
      client.instance_variable_set(:@access_token, token)
      
      expect(client.scopes).to eq([])
    end
    
    it 'returns empty array if no token exists' do
      client.instance_variable_set(:@access_token, nil)
      
      expect(client.scopes).to eq([])
    end
  end
  
  describe '#update_transport_auth' do
    let(:token) { double('OAuth2::AccessToken', token: 'access_token') }
    
    it 'updates transport auth token if transport responds to set_auth_token' do
      transport = double('Transport', headers: {})
      allow(transport).to receive(:respond_to?).with(:set_auth_token).and_return(true)
      expect(transport).to receive(:set_auth_token).with('access_token')
      
      client.instance_variable_set(:@transport, transport)
      
      client.send(:update_transport_auth, token)
    end
    
    it 'updates transport headers if transport does not respond to set_auth_token' do
      transport = double('Transport')
      allow(transport).to receive(:respond_to?).with(:set_auth_token).and_return(false)
      allow(transport).to receive(:respond_to?).with(:headers=).and_return(true)
      allow(transport).to receive(:headers).and_return({})
      
      client.instance_variable_set(:@transport, transport)
      
      client.send(:update_transport_auth, token)
      
      expect(transport.headers).to include('Authorization' => 'Bearer access_token')
    end
    
    it 'does nothing if no transport exists' do
      client.instance_variable_set(:@transport, nil)
      
      expect {
        client.send(:update_transport_auth, token)
      }.not_to raise_error
    end
    
    it 'does nothing if no token is provided' do
      expect {
        client.send(:update_transport_auth, nil)
      }.not_to raise_error
    end
  end
  
  describe '#setup_token_refresh' do
    let(:transport) { double('Transport') }
    
    before do
      client.instance_variable_set(:@transport, transport)
      allow(transport).to receive(:respond_to?).with(:on_event).and_return(true)
      allow(transport).to receive(:on_event)
    end
    
    it 'registers a refresh handler with the transport' do
      expect(transport).to receive(:on_event).with('auth.refresh')
      
      client.send(:setup_token_refresh)
    end
    
    it 'does nothing if transport does not respond to on_event' do
      allow(transport).to receive(:respond_to?).with(:on_event).and_return(false)
      
      expect(transport).not_to receive(:on_event)
      
      client.send(:setup_token_refresh)
    end
    
    it 'does nothing if no transport exists' do
      client.instance_variable_set(:@transport, nil)
      
      expect {
        client.send(:setup_token_refresh)
      }.not_to raise_error
    end
  end
end