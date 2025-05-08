#!/usr/bin/env ruby
# frozen_string_literal: true

require 'sinatra'
require 'json'
require 'securerandom'

# Simple OAuth server for testing
class OAuthServer < Sinatra::Base
  # Store tokens
  @@tokens = {}
  @@codes = {}
  
  # Authorization endpoint
  get '/oauth/authorize' do
    client_id = params[:client_id]
    redirect_uri = params[:redirect_uri]
    scope = params[:scope]
    state = params[:state]
    
    # Validate client ID
    unless client_id == 'example-client'
      return 400, 'Invalid client ID'
    end
    
    # Generate authorization code
    code = SecureRandom.hex(16)
    
    # Store the code
    @@codes[code] = {
      client_id: client_id,
      redirect_uri: redirect_uri,
      scope: scope,
      state: state,
      expires_at: Time.now.to_i + 600 # 10 minutes
    }
    
    # Redirect back to the client
    redirect "#{redirect_uri}?code=#{code}&state=#{state}"
  end
  
  # Token endpoint
  post '/oauth/token' do
    content_type :json
    
    # Get the grant type
    grant_type = params[:grant_type]
    
    if grant_type == 'authorization_code'
      # Exchange code for token
      code = params[:code]
      redirect_uri = params[:redirect_uri]
      client_id = params[:client_id]
      client_secret = params[:client_secret]
      
      # Validate client credentials
      unless client_id == 'example-client' && client_secret == 'example-secret'
        status 401
        return { error: 'invalid_client' }.to_json
      end
      
      # Validate the code
      code_data = @@codes[code]
      if !code_data || code_data[:expires_at] < Time.now.to_i
        status 400
        return { error: 'invalid_grant' }.to_json
      end
      
      # Validate redirect URI
      unless code_data[:redirect_uri] == redirect_uri
        status 400
        return { error: 'invalid_grant' }.to_json
      end
      
      # Generate access token
      access_token = SecureRandom.hex(32)
      refresh_token = SecureRandom.hex(32)
      
      # Store the token
      @@tokens[access_token] = {
        client_id: client_id,
        scope: code_data[:scope],
        expires_at: Time.now.to_i + 3600, # 1 hour
        refresh_token: refresh_token
      }
      
      # Delete the code
      @@codes.delete(code)
      
      # Return the token
      {
        access_token: access_token,
        token_type: 'bearer',
        expires_in: 3600,
        refresh_token: refresh_token,
        scope: code_data[:scope]
      }.to_json
    elsif grant_type == 'refresh_token'
      # Refresh token
      refresh_token = params[:refresh_token]
      client_id = params[:client_id]
      client_secret = params[:client_secret]
      
      # Validate client credentials
      unless client_id == 'example-client' && client_secret == 'example-secret'
        status 401
        return { error: 'invalid_client' }.to_json
      end
      
      # Find the token by refresh token
      token_data = @@tokens.values.find { |t| t[:refresh_token] == refresh_token }
      if !token_data
        status 400
        return { error: 'invalid_grant' }.to_json
      end
      
      # Generate new access token
      access_token = SecureRandom.hex(32)
      new_refresh_token = SecureRandom.hex(32)
      
      # Update the token
      @@tokens.each do |k, v|
        if v[:refresh_token] == refresh_token
          @@tokens.delete(k)
          break
        end
      end
      
      # Store the new token
      @@tokens[access_token] = {
        client_id: client_id,
        scope: token_data[:scope],
        expires_at: Time.now.to_i + 3600, # 1 hour
        refresh_token: new_refresh_token
      }
      
      # Return the token
      {
        access_token: access_token,
        token_type: 'bearer',
        expires_in: 3600,
        refresh_token: new_refresh_token,
        scope: token_data[:scope]
      }.to_json
    else
      status 400
      { error: 'unsupported_grant_type' }.to_json
    end
  end
  
  # Token validation endpoint
  get '/oauth/validate' do
    content_type :json
    
    # Get the token from the Authorization header
    auth_header = request.env['HTTP_AUTHORIZATION']
    if auth_header && auth_header.start_with?('Bearer ')
      token = auth_header[7..-1]
      
      # Validate the token
      token_data = @@tokens[token]
      if token_data && token_data[:expires_at] > Time.now.to_i
        {
          valid: true,
          client_id: token_data[:client_id],
          scope: token_data[:scope],
          expires_at: token_data[:expires_at]
        }.to_json
      else
        status 401
        { valid: false, error: 'invalid_token' }.to_json
      end
    else
      status 401
      { valid: false, error: 'missing_token' }.to_json
    end
  end
end

# If running directly, start the server
if __FILE__ == $0
  OAuthServer.run! host: 'localhost', port: 3001
end