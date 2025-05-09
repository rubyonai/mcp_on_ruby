# frozen_string_literal: true

require 'jwt'
require 'oauth2'
require 'securerandom'

module MCP
  module Server
    module Auth
      # OAuth 2.1 implementation for MCP server
      class OAuth
        attr_reader :client_id, :client_secret, :token_expiry, :jwt_secret, :issuer, :scopes
        
        # Initialize OAuth
        # @param options [Hash] OAuth options
        def initialize(options = {})
          @client_id = options[:client_id]
          @client_secret = options[:client_secret]
          @token_expiry = options[:token_expiry] || 3600 # 1 hour
          @jwt_secret = options[:jwt_secret] || SecureRandom.hex(32)
          @issuer = options[:issuer] || 'mcp_server'
          @scopes = options[:scopes] || ['mcp']
          @logger = MCP.logger
        end
        
        # Create a JWT from token parameters
        # @param token [OAuth2::AccessToken] The token with parameters
        # @return [String] The JWT
        def create_jwt(token)
          # Extract user ID from token parameters - ensure we set the sub field
          user_id = token.params['user_id'] || token.params['sub']
          
          # Extract scopes from token parameters or use default scopes
          scopes = if token.params['scope']
                     token.params['scope'].split(' ')
                   else
                     @scopes
                   end
          
          # Create JWT payload with string keys for proper JWT serialization
          payload = {
            'sub' => user_id,
            'exp' => Time.now.to_i + @token_expiry,
            'iat' => Time.now.to_i,
            'iss' => @issuer,
            'scopes' => scopes
          }
          
          # Encode JWT
          JWT.encode(payload, @jwt_secret, 'HS256')
        end
        
        # Verify a JWT
        # @param token [String] The token to verify
        # @return [Hash, nil] The payload if valid, nil if invalid
        def verify_jwt(token)
          begin
            decoded = JWT.decode(token, @jwt_secret, true, { algorithm: 'HS256' })
            decoded[0] # Return the payload
          rescue JWT::DecodeError, JWT::ExpiredSignature => e
            @logger&.error("JWT verification failed: #{e.message}") if @logger
            nil
          end
        end
        
        # Authenticate client credentials
        # @param client_id [String] The client ID
        # @param client_secret [String] The client secret
        # @return [Boolean] true if valid credentials
        def authenticate_client(client_id, client_secret)
          client_id == @client_id && client_secret == @client_secret
        end
        
        # Create an OAuth2 token
        # @param params [Hash] Token parameters
        # @return [OAuth2::AccessToken] The token
        def create_token(params)
          client = OAuth2::Client.new(@client_id, @client_secret)
          
          # Create a deep copy of the params to avoid modifying the original
          token_params = params.dup
          
          # Set default scope if not provided
          token_params['scope'] ||= @scopes.join(' ')
          
          # Create token
          OAuth2::AccessToken.new(
            client,
            SecureRandom.hex(16),
            refresh_token: SecureRandom.hex(16),
            expires_in: @token_expiry,
            params: token_params
          )
        end
        
        # Verify if a token has a required scope
        # @param token_payload [Hash] The token payload
        # @param required_scope [String] The required scope
        # @return [Boolean] true if token has the scope
        def verify_scope(token_payload, required_scope)
          return false unless token_payload && token_payload['scopes']
          
          scopes = token_payload['scopes']
          return false if scopes.nil? || scopes.empty?
          
          scopes.include?(required_scope)
        end
      end
    end
  end
end