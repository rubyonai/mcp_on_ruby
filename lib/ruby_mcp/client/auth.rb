# frozen_string_literal: true

require 'oauth2'

module MCP
  module Client
    # Authentication functionality for client
    module Auth
      # Set OAuth credentials
      # @param options [Hash] OAuth options
      def set_oauth_credentials(options)
        @oauth_options = options
        @oauth_client = create_oauth_client(options)
        
        # Set up auto-refresh if enabled
        setup_token_refresh if options[:auto_refresh]
      end
      
      # Get an authorization URL
      # @param state [String] State parameter for CSRF protection
      # @param redirect_uri [String] The redirect URI
      # @param scopes [Array<String>] The requested scopes
      # @return [String] The authorization URL
      def authorization_url(state, redirect_uri = nil, scopes = nil)
        ensure_oauth_client
        
        @oauth_client.auth_code.authorize_url(
          redirect_uri: redirect_uri || @oauth_options[:redirect_uri],
          scope: scopes || @oauth_options[:scopes] || 'mcp',
          state: state
        )
      end
      
      # Exchange an authorization code for a token
      # @param code [String] The authorization code
      # @param redirect_uri [String] The redirect URI
      # @return [OAuth2::AccessToken] The access token
      def exchange_code(code, redirect_uri = nil)
        ensure_oauth_client
        
        @oauth_client.auth_code.get_token(
          code,
          redirect_uri: redirect_uri || @oauth_options[:redirect_uri]
        ).tap do |token|
          @access_token = token
          update_transport_auth(token)
        end
      end
      
      # Refresh the access token
      # @return [OAuth2::AccessToken] The refreshed access token
      def refresh_token
        ensure_oauth_client
        
        if @access_token && @access_token.refresh_token
          @logger&.info("Refreshing access token")
          @access_token = @access_token.refresh!.tap do |token|
            update_transport_auth(token)
          end
        else
          raise MCP::Errors::AuthenticationError, "No refresh token available"
        end
      end
      
      # Set an access token directly
      # @param token [String, OAuth2::AccessToken] The access token
      def set_access_token(token)
        if token.is_a?(String)
          ensure_oauth_client
          @access_token = OAuth2::AccessToken.new(@oauth_client, token)
        else
          @access_token = token
        end
        
        update_transport_auth(@access_token)
      end
      
      # Get the current access token
      # @return [OAuth2::AccessToken, nil] The current access token
      def access_token
        @access_token
      end
      
      # Check if the client has valid credentials
      # @return [Boolean] true if the client has valid credentials
      def authenticated?
        !@access_token.nil? && !@access_token.expired?
      end
      
      # Return the current token scopes
      # @return [Array<String>] The token scopes
      def scopes
        return [] unless @access_token
        
        # Extract scopes from token
        if @access_token.params['scope']
          @access_token.params['scope'].split(' ')
        else
          []
        end
      end
      
      private
      
      # Create an OAuth client
      # @param options [Hash] OAuth options
      # @return [OAuth2::Client] The OAuth client
      def create_oauth_client(options)
        OAuth2::Client.new(
          options[:client_id],
          options[:client_secret],
          site: options[:site],
          authorize_url: options[:authorize_url],
          token_url: options[:token_url]
        )
      end
      
      # Ensure an OAuth client exists
      # @raise [MCP::Errors::AuthenticationError] If no OAuth client is available
      def ensure_oauth_client
        if !@oauth_client
          raise MCP::Errors::AuthenticationError, "No OAuth client available"
        end
      end
      
      # Update the transport authentication
      # @param token [OAuth2::AccessToken] The access token
      def update_transport_auth(token)
        return unless token
        
        # Update the transport if it exists and supports the new auth methods
        if @transport
          if @transport.respond_to?(:set_auth_token)
            @transport.set_auth_token(token.token)
          elsif @transport.respond_to?(:headers=)
            @transport.headers ||= {}
            @transport.headers['Authorization'] = "Bearer #{token.token}"
          end
        end
      end
      
      # Set up automatic token refresh
      def setup_token_refresh
        return unless @transport && @transport.respond_to?(:on_event)
        
        # Register a handler for auth refresh events
        @transport.on_event('auth.refresh') do
          begin
            refresh_token
          rescue => e
            @logger&.error("Error refreshing token: #{e.message}")
            # Trigger authentication error event
            @transport.on_event('auth.error')&.call(e)
          end
        end
      end
    end
  end
end