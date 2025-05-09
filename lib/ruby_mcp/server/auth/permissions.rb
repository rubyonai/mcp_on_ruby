# frozen_string_literal: true

module MCP
  module Server
    module Auth
      # Permission management for MCP server
      class Permissions
        # Initialize permissions
        def initialize
          @method_scopes = {}
        end
        
        # Create a default permissions manager
        # @return [MCP::Server::Auth::Permissions] The default permissions manager
        def self.create_default
          permissions = new
          permissions.load_default_scopes
          permissions
        end
        
        # Add a method with required scopes
        # @param method [String] The method name
        # @param scopes [Array<String>] The required scopes
        def add_method(method, scopes)
          @method_scopes[method] = scopes
        end
        
        # Add multiple methods with their scopes
        # @param method_scopes [Hash] A hash of method => scopes mappings
        def add_methods(method_scopes)
          method_scopes.each do |method, scopes|
            add_method(method, scopes)
          end
        end
        
        # Get the required scopes for a method
        # @param method [String] The method name
        # @return [Array<String>, nil] The required scopes or nil if method not found
        def get_required_scopes(method)
          @method_scopes[method]
        end
        
        # Check if a token has permission to access a method
        # @param token [Hash] The token payload with scopes
        # @param method [String] The method to check permission for
        # @return [Boolean] true if the token has permission
        def check_permission(token, method)
          # If method doesn't require scopes, allow access
          required_scopes = get_required_scopes(method)
          return true unless required_scopes
          
          # If token is nil or has no scopes, deny access
          return false unless token && token['scopes']
          
          # Check if token has any of the required scopes
          token_scopes = token['scopes']
          return false if token_scopes.empty?
          
          required_scopes.any? { |scope| token_scopes.include?(scope) }
        end
        
        # Load default method scopes
        def load_default_scopes
          default_scopes = {
            'tools/list' => ['tools:read'],
            'tools/call' => ['tools:call', 'tools:write'],
            'resources/list' => ['resources:read'],
            'resources/get' => ['resources:read'],
            'prompts/list' => ['prompts:read'],
            'prompts/show' => ['prompts:read'],
            'roots/list' => ['roots:read'],
            'roots/list_files' => ['roots:read'],
            'roots/read_file' => ['roots:read'],
            'roots/write_file' => ['roots:write']
          }
          
          add_methods(default_scopes)
        end
      end
    end
  end
end