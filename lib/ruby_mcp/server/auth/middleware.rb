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
          @logger = MCP.logger
        end
        
        # Call the middleware
        # @param env [Hash] The Rack environment
        # @return [Array] The Rack response
        def call(env)
          # Check for authentication
          token = extract_token(env)
          
          # If authentication is enabled and no token is provided, return 401
          if @auth_provider && !token
            return [401, { 'Content-Type' => 'application/json' }, [{ error: 'Unauthorized' }.to_json]]
          end
          
          # If token is provided, verify it
          if token
            payload = @auth_provider.verify_jwt(token)
            
            # If token is invalid, return 401
            if !payload
              return [401, { 'Content-Type' => 'application/json' }, [{ error: 'Invalid token' }.to_json]]
            end
            
            # Check if the request is a JSON-RPC request
            if is_jsonrpc_request?(env)
              # Verify method permission
              method = extract_jsonrpc_method(env)
              
              if method && !@permissions.check_permission(token, method)
                return [403, { 'Content-Type' => 'application/json' }, [{ error: 'Forbidden' }.to_json]]
              end
            end
            
            # Store JWT payload in env for later use
            env['mcp.auth.payload'] = payload
          end
          
          # Call the next middleware
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
          return false unless env['CONTENT_TYPE']&.include?('application/json')
          
          # Only check POST requests
          return false unless env['REQUEST_METHOD'] == 'POST'
          
          # Parse the request body
          begin
            body = env['rack.input'].read
            env['rack.input'].rewind
            
            data = JSON.parse(body)
            
            # Check if the request has the required JSON-RPC fields
            data['jsonrpc'] == '2.0' && data['method'].is_a?(String)
          rescue
            false
          end
        end
        
        # Extract JSON-RPC method from request
        # @param env [Hash] The Rack environment
        # @return [String, nil] The method, or nil if not found
        def extract_jsonrpc_method(env)
          body = env['rack.input'].read
          env['rack.input'].rewind
          
          begin
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