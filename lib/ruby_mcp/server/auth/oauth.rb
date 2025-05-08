# frozen_string_literal: true

require 'oauth2'
require 'jwt'

module MCP
  module Server
    module Auth
      # OAuth 2.1 implementation for MCP server
      class OAuth
        attr_reader :issuer, :client_id, :client_secret, :redirect_uri
        
        # Initialize OAuth
        # @param options [Hash] OAuth options
        def initialize(options = {})
          @issuer = options[:issuer]
          @client_id = options[:client_id]
          @client_secret = options[:client_secret]
          @redirect_uri = options[:redirect_uri]
          @jwt_secret = options[:jwt_secret]
          @token_expiry = options[:token_expiry] || 3600 # 1 hour
          @authorization_endpoint = options[:authorization_endpoint]
          @token_endpoint = options[:token_endpoint]
          @scopes = options[:scopes] || ['mcp']
          @logger = MCP.logger
          
          validate_options!
        end
        
        # Create an authorization URL
        # @param state [String] State parameter for CSRF protection
        # @param scopes [Array<String>] Requested scopes
        # @return [String] The authorization URL
        def authorization_url(state, scopes = nil)
          client = create_client
          
          client.auth_code.authorize_url(
            redirect_uri: @redirect_uri,
            scope: scopes || @scopes,
            state: state
          )
        end
        
        # Exchange an authorization code for a token
        # @param code [String] The authorization code
        # @return [OAuth2::AccessToken] The access token
        def exchange_code(code)
          client = create_client
          
          client.auth_code.get_token(
            code,
            redirect_uri: @redirect_uri
          )
        end
        
        # Create a JWT from an access token
        # @param token [OAuth2::AccessToken] The access token
        # @return [String] The JWT
        def create_jwt(token)
          payload = {
            sub: token.params['user_id'] || token.params['sub'],
            exp: Time.now.to_i + @token_expiry,
            iat: Time.now.to_i,
            iss: @issuer,
            scopes: token.params['scope']&.split(' ') || @scopes
          }
          
          JWT.encode(payload, @jwt_secret, 'HS256')
        end
        
        # Verify a JWT
        # @param jwt [String] The JWT to verify
        # @return [Hash] The decoded JWT payload
        def verify_jwt(jwt)
          begin
            decoded = JWT.decode(jwt, @jwt_secret, true, { algorithm: 'HS256' })
            decoded[0] # Return the payload
          rescue JWT::DecodeError => e
            @logger.error("JWT verification failed: #{e.message}")
            nil
          end
        end
        
        # Check if a JWT has a specific scope
        # @param jwt [String] The JWT to check
        # @param scope [String] The scope to check for
        # @return [Boolean] true if the JWT has the scope
        def has_scope?(jwt, scope)
          payload = verify_jwt(jwt)
          return false unless payload
          
          scopes = payload['scopes'] || []
          scopes.include?(scope)
        end
        
        private
        
        # Create an OAuth client
        # @return [OAuth2::Client] The OAuth client
        def create_client
          OAuth2::Client.new(
            @client_id,
            @client_secret,
            site: @issuer,
            authorize_url: @authorization_endpoint,
            token_url: @token_endpoint
          )
        end
        
        # Validate required options
        # @raise [MCP::Errors::AuthenticationError] If required options are missing
        def validate_options!
          unless @issuer && @client_id && @client_secret && @redirect_uri && @jwt_secret
            raise MCP::Errors::AuthenticationError, "Missing required OAuth options"
          end
        end
      end
    end
  end
end