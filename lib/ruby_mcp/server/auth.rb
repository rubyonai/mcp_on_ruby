# frozen_string_literal: true

require_relative 'auth/oauth'
require_relative 'auth/permissions'
require_relative 'auth/middleware'

module MCP
  module Server
    # Authentication module for server
    module Auth
      # Create an OAuth provider
      # @param options [Hash] OAuth options
      # @return [OAuth] The OAuth provider
      def self.create_oauth_provider(options)
        OAuth.new(options)
      end
      
      # Create a permissions manager
      # @param auth_provider [OAuth] The auth provider
      # @return [Permissions] The permissions manager
      def self.create_permissions_manager(auth_provider)
        Permissions.new(auth_provider)
      end
      
      # Create authentication middleware
      # @param app [Proc] The Rack application
      # @param auth_provider [OAuth] The auth provider
      # @param permissions [Permissions] The permissions manager
      # @return [Middleware] The middleware
      def self.create_middleware(app, auth_provider, permissions)
        Middleware.new(app, auth_provider, permissions)
      end
    end
  end
end