# frozen_string_literal: true

module MCP
  module Server
    module Auth
      # Permission management for MCP server
      class Permissions
        # Initialize permissions
        # @param auth_provider [MCP::Server::Auth::OAuth] The auth provider
        def initialize(auth_provider)
          @auth_provider = auth_provider
          @permission_map = {
            'tools/list' => ['mcp:tools:read'],
            'tools/call' => ['mcp:tools:execute'],
            'resources/list' => ['mcp:resources:read'],
            'resources/listResourceTemplates' => ['mcp:resources:read'],
            'resources/read' => ['mcp:resources:read'],
            'prompts/list' => ['mcp:prompts:read'],
            'prompts/get' => ['mcp:prompts:read'],
            'roots/list' => ['mcp:roots:read'],
            'roots/read' => ['mcp:roots:read'],
            'roots/write' => ['mcp:roots:write']
          }
          @logger = MCP.logger
        end
        
        # Check if a JWT has permission to access a method
        # @param jwt [String] The JWT to check
        # @param method [String] The method to check permission for
        # @return [Boolean] true if the JWT has permission
        def check_permission(jwt, method)
          # If no auth provider, deny access
          return false unless @auth_provider
          
          # Get required scopes for the method
          required_scopes = @permission_map[method] || []
          
          # If method doesn't require scopes, allow access
          return true if required_scopes.empty?
          
          # Check if JWT has any of the required scopes
          required_scopes.any? { |scope| @auth_provider.has_scope?(jwt, scope) }
        end
        
        # Register permission requirements for a method
        # @param method [String] The method name
        # @param scopes [Array<String>] The required scopes
        def register_permission(method, scopes)
          @permission_map[method] = scopes
        end
        
        # Get the required scopes for a method
        # @param method [String] The method name
        # @return [Array<String>] The required scopes
        def required_scopes(method)
          @permission_map[method] || []
        end
      end
    end
  end
end