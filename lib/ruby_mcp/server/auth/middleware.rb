# frozen_string_literal: true

module MCP
  module Server
    module Auth
      # Authentication middleware for HTTP transport
      class Middleware
        # Initialize middleware
        # @param app [Proc] The Rack application
        # @param auth_provider [MCP::Server::Auth::OAuth] The auth provider
        # @param permissions [MCP::Server::Auth::Permissions] The permissions manager
        def initialize(app, auth_provider, permissions)
          @app = app
          @auth_provider = auth_provider
          @permissions = permissions
        end
        
        # Call the middleware
        # @param env [Hash] The Rack environment
        # @return [Array] The Rack response
        def call(env)
          # Skip authentication if auth_provider is nil
          if @auth_provider.nil?
            return @app.call(env)
          end
          
          # Extract token from request
          token = extract_token(env)
          
          # If no token is provided, return unauthorized
          if token.nil?
            return [401, { 'Content-Type' => 'application/json' }, [{ error: 'Unauthorized' }.to_json]]
          end
          
          # Verify token
          token_payload = @auth_provider.verify_jwt(token)
          
          # If token is invalid, return unauthorized
          if token_payload.nil?
            return [401, { 'Content-Type' => 'application/json' }, [{ error: 'Invalid token' }.to_json]]
          end
          
          # Check JSON-RPC method permission
          if is_jsonrpc_request?(env)
            method = extract_jsonrpc_method(env)
            
            if method && !@permissions.check_permission(token_payload, method)
              return [403, { 'Content-Type' => 'application/json' }, [{ error: 'Forbidden' }.to_json]]
            end
          end
          
          # Add token payload to environment
          env['mcp.auth.payload'] = token_payload
          
          # Call next middleware
          @app.call(env)
        end
        
        private
        
        # Extract token from request
        # @param env [Hash] The Rack environment
        # @return [String, nil] The token, or nil if not found
        def extract_token(env)
          auth_header = env['HTTP_AUTHORIZATION']
          return nil unless auth_header
          
          # Extract the token from the authorization header
          if auth_header.start_with?('Bearer ')
            auth_header[7..-1]
          else
            nil
          end
        end
        
        # Check if request is a JSON-RPC request
        # @param env [Hash] The Rack environment
        # @return [Boolean] true if the request is a JSON-RPC request
        def is_jsonrpc_request?(env)
          # Check content type
          return false unless env['CONTENT_TYPE']&.include?('application/json')
          
          # Check request method
          return false unless env['REQUEST_METHOD'] == 'POST'
          
          # Parse and check request body
          begin
            body = env['rack.input'].read
            env['rack.input'].rewind
            
            data = JSON.parse(body)
            
            # Check if body has required JSON-RPC fields
            data.key?('jsonrpc') && data.key?('method')
          rescue
            false
          end
        end
        
        # Extract JSON-RPC method from request
        # @param env [Hash] The Rack environment
        # @return [String, nil] The method, or nil if not found
        def extract_jsonrpc_method(env)
          begin
            body = env['rack.input'].read
            env['rack.input'].rewind
            
            data = JSON.parse(body)
            data['method']
          rescue
            nil
          end
        end
      end
    end
  end
end