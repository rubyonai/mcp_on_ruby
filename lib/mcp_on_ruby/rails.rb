# frozen_string_literal: true

require 'rails' if defined?(Rails)

module MCP
  module Rails
    # Rails controller for handling MCP requests
    class Controller < ActionController::Base
      skip_before_action :verify_authenticity_token
      before_action :authenticate_mcp_request, if: :authentication_required?
      
      def handle
        server = mcp_server
        response_data = server.handle_request(
          request.body.read,
          headers: request.headers
        )
        
        if response_data
          render json: response_data
        else
          head :no_content
        end
      rescue => e
        Rails.logger.error "MCP Request Error: #{e.message}"
        render json: { 
          jsonrpc: "2.0", 
          error: { code: -32603, message: "Internal error" },
          id: nil 
        }, status: 500
      end
      
      private
      
      def mcp_server
        @mcp_server ||= ::Rails.application.config.mcp_server
      end
      
      def authenticate_mcp_request
        # Override in subclass for custom authentication
        # Default: check for Authorization header
        auth_header = request.headers['Authorization']
        token = auth_header&.sub(/^Bearer\s+/, '')
        
        unless valid_mcp_token?(token)
          render json: {
            jsonrpc: "2.0",
            error: { code: -32600, message: "Unauthorized" },
            id: nil
          }, status: 401
        end
      end
      
      def valid_mcp_token?(token)
        # Override in subclass for custom token validation
        # Default: check against configured token
        return true unless authentication_required?
        token == mcp_token
      end
      
      def authentication_required?
        ::Rails.application.config.mcp_authentication_required || false
      end
      
      def mcp_token
        ::Rails.application.config.mcp_token
      end
    end
    
    # Rack middleware for MCP
    class Middleware
      def initialize(app, &block)
        @app = app
        @server = MCP::Server.new
        yield(@server) if block_given?
      end
      
      def call(env)
        if mcp_request?(env)
          handle_mcp_request(env)
        else
          @app.call(env)
        end
      end
      
      private
      
      def mcp_request?(env)
        env['REQUEST_METHOD'] == 'POST' && 
        env['PATH_INFO'] == '/mcp' &&
        env['CONTENT_TYPE']&.include?('application/json')
      end
      
      def handle_mcp_request(env)
        request_body = env['rack.input'].read
        response_data = @server.handle_request(request_body)
        
        if response_data
          [
            200,
            { 'Content-Type' => 'application/json' },
            [JSON.generate(response_data)]
          ]
        else
          [204, {}, []]
        end
      rescue => e
        error_response = {
          jsonrpc: "2.0",
          error: { code: -32603, message: "Internal error" },
          id: nil
        }
        
        [
          500,
          { 'Content-Type' => 'application/json' },
          [JSON.generate(error_response)]
        ]
      end
    end
    
    # Configuration helper
    module Configuration
      def self.setup
        ::Rails.application.configure do
          # Default MCP configuration
          config.mcp_authentication_required = false
          config.mcp_token = nil
          
          # Initialize MCP server after Rails loads
          config.after_initialize do
            config.mcp_server = MCP::Server.new unless config.mcp_server
          end
        end
      end
    end
  end
end

# Auto-setup for Rails applications
if defined?(Rails::Railtie)
  class MCPRailtie < Rails::Railtie
    initializer "mcp.configure" do
      MCP::Rails::Configuration.setup
    end
  end
end