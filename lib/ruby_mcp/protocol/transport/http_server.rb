# frozen_string_literal: true

require 'rack'
require 'rack/handler/webrick'
require 'json'
require 'faye/websocket'

module MCP
  module Protocol
    module Transport
      # HTTP server implementation for MCP
      class HTTPServer
        attr_reader :app, :server, :options
        
        def initialize(options = {})
          @options = options
          @port = options[:port] || 3000
          @host = options[:host] || 'localhost'
          @path = options[:path] || '/mcp'
          @server = nil
          @logger = options[:logger] || MCP.logger
          @message_handler = options[:message_handler]
          @auth_provider = options[:auth_provider]
          @permissions = options[:permissions]
          
          # Create Rack application
          @app = build_rack_app
        end
        
        # Start the HTTP server
        # @return [HTTPServer] self
        def start
          return self if running?
          
          Thread.new do
            begin
              Rack::Handler::WEBrick.run(
                @app,
                Host: @host,
                Port: @port,
                Logger: WEBrick::Log.new('/dev/null'),
                AccessLog: []
              )
            rescue => e
              @logger.error("Error starting HTTP server: #{e.message}")
            end
          end
          
          @logger.info("HTTP server started on #{@host}:#{@port}#{@path}")
          self
        end
        
        # Stop the HTTP server
        def stop
          Rack::Handler::WEBrick.shutdown
          @logger.info("HTTP server stopped")
        end
        
        # Check if the server is running
        # @return [Boolean] true if running
        def running?
          # TODO: Implement proper check
          !@server.nil?
        end
        
        # Set the authentication provider and permissions manager
        # @param auth_provider [MCP::Server::Auth::OAuth] The auth provider
        # @param permissions [MCP::Server::Auth::Permissions] The permissions manager
        def set_auth_middleware(auth_provider, permissions)
          @auth_provider = auth_provider
          @permissions = permissions
          # Rebuild the rack app to include the auth middleware
          @app = build_rack_app
          @logger.info("Authentication middleware configured")
        end
        
        private
        
        # Build the Rack application with middleware
        # @return [#call] The Rack application
        def build_rack_app
          app = Rack::Builder.new do
            # WebSocket handler
            map '/mcp' do
              run lambda { |env|
                if Faye::WebSocket.websocket?(env)
                  ws = Faye::WebSocket.new(env)
                  
                  ws.on :message do |event|
                    # Handle incoming message
                    handle_websocket_message(ws, event.data, env)
                  end
                  
                  ws.on :close do |event|
                    # Handle connection close
                  end
                  
                  ws.rack_response
                else
                  # Handle HTTP request
                  [404, { 'Content-Type' => 'text/plain' }, ['Not Found']]
                end
              }
            end
            
            # HTTP API endpoint
            map '/mcp/api' do
              run lambda { |env|
                if env['REQUEST_METHOD'] == 'POST' && env['CONTENT_TYPE']&.include?('application/json')
                  # Read and parse the request body
                  request_body = env['rack.input'].read
                  env['rack.input'].rewind
                  
                  begin
                    message = JSON.parse(request_body, symbolize_names: true)
                    
                    # Handle the JSON-RPC request
                    result = handle_jsonrpc_message(message, env)
                    
                    # Return the result
                    [200, { 'Content-Type' => 'application/json' }, [result.to_json]]
                  rescue => e
                    # Return JSON-RPC error
                    error = {
                      jsonrpc: '2.0',
                      error: {
                        code: -32700,
                        message: 'Parse error'
                      },
                      id: nil
                    }
                    
                    [400, { 'Content-Type' => 'application/json' }, [error.to_json]]
                  end
                else
                  # Method not allowed
                  [405, { 'Content-Type' => 'text/plain' }, ['Method Not Allowed']]
                end
              }
            end
          end
          
          # Add authentication middleware if configured
          if @auth_provider && @permissions
            app = Rack::Builder.new do
              use MCP::Server::Auth::Middleware, @auth_provider, @permissions
              run app
            end
          end
          
          app
        end
        
        # Handle a WebSocket message
        # @param ws [Faye::WebSocket] The WebSocket connection
        # @param data [String] The message data
        # @param env [Hash] The Rack environment
        def handle_websocket_message(ws, data, env)
          begin
            message = JSON.parse(data, symbolize_names: true)
            
            # Check authentication if middleware is configured
            if @auth_provider && @permissions
              # Extract auth payload from env (set by middleware)
              auth_payload = env['mcp.auth.payload']
              
              # If no auth payload, the request is unauthorized
              if !auth_payload
                error = {
                  jsonrpc: '2.0',
                  error: {
                    code: -32000,
                    message: 'Unauthorized'
                  },
                  id: message[:id]
                }
                
                ws.send(error.to_json)
                return
              end
              
              # Check permission for the method
              if message[:method] && !@permissions.check_permission(auth_payload, message[:method])
                error = {
                  jsonrpc: '2.0',
                  error: {
                    code: -32000,
                    message: 'Forbidden'
                  },
                  id: message[:id]
                }
                
                ws.send(error.to_json)
                return
              end
            end
            
            # Process the message
            if @message_handler
              result = @message_handler.call(message)
              
              # Send the result back if it's a request
              if message[:id]
                response = {
                  jsonrpc: '2.0',
                  result: result,
                  id: message[:id]
                }
                
                ws.send(response.to_json)
              end
            end
          rescue => e
            @logger.error("Error handling WebSocket message: #{e.message}")
            
            # Send error response if it's a request
            if message && message[:id]
              error = {
                jsonrpc: '2.0',
                error: {
                  code: -32603,
                  message: 'Internal error'
                },
                id: message[:id]
              }
              
              ws.send(error.to_json)
            end
          end
        end
        
        # Handle a JSON-RPC message
        # @param message [Hash] The JSON-RPC message
        # @param env [Hash] The Rack environment
        # @return [Hash] The JSON-RPC response
        def handle_jsonrpc_message(message, env)
          # Check authentication if middleware is configured
          if @auth_provider && @permissions
            # Extract auth payload from env (set by middleware)
            auth_payload = env['mcp.auth.payload']
            
            # If no auth payload, the request is unauthorized
            if !auth_payload
              return {
                jsonrpc: '2.0',
                error: {
                  code: -32000,
                  message: 'Unauthorized'
                },
                id: message[:id]
              }
            end
            
            # Check permission for the method
            if message[:method] && !@permissions.check_permission(auth_payload, message[:method])
              return {
                jsonrpc: '2.0',
                error: {
                  code: -32000,
                  message: 'Forbidden'
                },
                id: message[:id]
              }
            end
          end
          
          # Process the message
          if @message_handler
            begin
              result = @message_handler.call(message)
              
              # Return the result if it's a request
              if message[:id]
                {
                  jsonrpc: '2.0',
                  result: result,
                  id: message[:id]
                }
              else
                # For notifications, return empty response
                {}
              end
            rescue => e
              @logger.error("Error handling JSON-RPC message: #{e.message}")
              
              # Return error response if it's a request
              if message[:id]
                {
                  jsonrpc: '2.0',
                  error: {
                    code: -32603,
                    message: 'Internal error'
                  },
                  id: message[:id]
                }
              else
                # For notifications, return empty response
                {}
              end
            end
          else
            # No message handler configured
            {
              jsonrpc: '2.0',
              error: {
                code: -32603,
                message: 'Method not implemented'
              },
              id: message[:id]
            }
          end
        end
      end
    end
  end
end