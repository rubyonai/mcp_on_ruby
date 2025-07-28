# frozen_string_literal: true

module McpOnRuby
  module Transport
    # Rack middleware for handling MCP requests
    class RackMiddleware
      def initialize(app, server:, **options)
        @app = app
        @server = server
        @path = options[:path] || @server.configuration.path
        @logger = McpOnRuby.logger
        @options = options
      end

      def call(env)
        request = Rack::Request.new(env)
        
        # Only handle requests to our MCP path
        return @app.call(env) unless request.path == @path
        
        # Only handle POST requests for JSON-RPC
        return method_not_allowed_response unless request.post?
        
        # Security checks
        security_result = check_security(request)
        return security_result if security_result
        
        # Handle MCP request
        handle_mcp_request(request)
        
      rescue => error
        @logger.error("Transport error: #{error.message}")
        @logger.error(error.backtrace.join("\n"))
        internal_error_response
      end

      private

      def handle_mcp_request(request)
        # Build request context
        context = build_request_context(request)
        
        # Read request body
        request_body = request.body.read
        
        # Handle the request through server
        response_json = @server.handle_request(request_body, context)
        
        if response_json
          # JSON-RPC response
          json_response(response_json)
        else
          # Notification (no response)
          [204, cors_headers, []]
        end
      end

      def build_request_context(request)
        {
          remote_ip: request.ip,
          user_agent: request.user_agent,
          headers: request.env.select { |k, _| k.start_with?('HTTP_') },
          authenticated: authenticated?(request),
          auth_token: extract_auth_token(request)
        }
      end

      def check_security(request)
        config = @server.configuration
        
        # DNS rebinding protection
        if config.dns_rebinding_protection
          origin = request.get_header('HTTP_ORIGIN')
          host = request.get_header('HTTP_HOST')
          
          if origin && !origin_allowed?(origin, host)
            return forbidden_response("Origin not allowed: #{origin}")
          end
        end
        
        # Authentication check
        if config.authentication_required
          unless authenticated?(request)
            return unauthorized_response
          end
        end
        
        # Localhost only check
        if config.localhost_only
          unless localhost_request?(request)
            return forbidden_response("Localhost only mode enabled")
          end
        end
        
        nil # No security issues
      end

      def origin_allowed?(origin, host)
        config = @server.configuration
        
        # Check localhost patterns if localhost_only is enabled
        return false if config.localhost_only && !config.localhost_allowed?(origin)
        
        # Check configured allowed origins
        return config.origin_allowed?(origin) unless config.allowed_origins.empty?
        
        # Default: allow same origin
        origin_host = URI.parse(origin).host rescue nil
        origin_host == host
      end

      def authenticated?(request)
        return true unless @server.configuration.authentication_required
        
        token = extract_auth_token(request)
        token && token == @server.configuration.authentication_token
      end

      def extract_auth_token(request)
        auth_header = request.get_header('HTTP_AUTHORIZATION')
        return nil unless auth_header
        
        # Support Bearer token format
        if auth_header.start_with?('Bearer ')
          auth_header[7..-1]
        else
          auth_header
        end
      end

      def localhost_request?(request)
        ip = request.ip
        %w[127.0.0.1 ::1 localhost].include?(ip) || ip.start_with?('127.')
      end

      def cors_headers
        headers = {}
        
        if @server.configuration.cors_enabled
          headers['Access-Control-Allow-Origin'] = '*'
          headers['Access-Control-Allow-Methods'] = 'POST, OPTIONS'
          headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
          headers['Access-Control-Max-Age'] = '86400'
        end
        
        headers['Content-Type'] = 'application/json'
        headers
      end

      def json_response(json_body)
        [200, cors_headers, [json_body]]
      end

      def method_not_allowed_response
        [405, cors_headers.merge('Allow' => 'POST'), ['{"error": "Method not allowed"}']]
      end

      def unauthorized_response
        error_body = {
          jsonrpc: "2.0",
          error: { code: -32600, message: "Unauthorized" },
          id: nil
        }
        [401, cors_headers, [JSON.generate(error_body)]]
      end

      def forbidden_response(message = "Forbidden")
        error_body = {
          jsonrpc: "2.0",
          error: { code: -32600, message: message },
          id: nil
        }
        [403, cors_headers, [JSON.generate(error_body)]]
      end

      def internal_error_response
        error_body = {
          jsonrpc: "2.0",
          error: { code: -32603, message: "Internal error" },
          id: nil
        }
        [500, cors_headers, [JSON.generate(error_body)]]
      end
    end

    # SSE (Server-Sent Events) transport for real-time updates
    class SSETransport
      def initialize(server, **options)
        @server = server
        @options = options
        @logger = McpOnRuby.logger
        @clients = {}
        @mutex = Mutex.new
      end

      def call(env)
        request = Rack::Request.new(env)
        
        # Only handle GET requests for SSE
        return [405, {}, ['Method not allowed']] unless request.get?
        
        # Security checks (reuse from RackMiddleware)
        # ... security implementation similar to RackMiddleware
        
        # Handle SSE connection
        handle_sse_connection(env, request)
      end

      private

      def handle_sse_connection(env, request)
        # Hijack the connection for SSE
        if env['rack.hijack?']
          env['rack.hijack'].call
          io = env['rack.hijack_io']
          
          # Send SSE headers
          io.write("HTTP/1.1 200 OK\r\n")
          io.write("Content-Type: text/event-stream\r\n")
          io.write("Cache-Control: no-cache\r\n")
          io.write("Connection: keep-alive\r\n")
          io.write("\r\n")
          
          # Register client
          client_id = SecureRandom.uuid
          register_client(client_id, io, request)
          
          # Keep connection alive
          keep_alive_loop(client_id, io)
        else
          [500, {}, ['SSE not supported - server must support connection hijacking']]
        end
      end

      def register_client(client_id, io, request)
        @mutex.synchronize do
          @clients[client_id] = {
            io: io,
            context: build_request_context(request),
            last_seen: Time.now
          }
        end
        
        @logger.info("SSE client connected: #{client_id}")
        
        # Send welcome message
        send_event(client_id, 'connected', { clientId: client_id })
      end

      def keep_alive_loop(client_id, io)
        loop do
          begin
            # Send periodic ping
            send_event(client_id, 'ping', { timestamp: Time.now.iso8601 })
            sleep(30)
            
            # Check if client is still connected
            break unless client_connected?(client_id)
          rescue => error
            @logger.warn("SSE client #{client_id} disconnected: #{error.message}")
            break
          end
        end
      ensure
        unregister_client(client_id)
      end

      def send_event(client_id, event_type, data)
        client = nil
        @mutex.synchronize { client = @clients[client_id] }
        return unless client
        
        begin
          io = client[:io]
          io.write("event: #{event_type}\n")
          io.write("data: #{JSON.generate(data)}\n")
          io.write("\n")
          io.flush
          
          # Update last seen
          @mutex.synchronize { @clients[client_id][:last_seen] = Time.now }
        rescue => error
          @logger.warn("Failed to send SSE event to #{client_id}: #{error.message}")
          unregister_client(client_id)
        end
      end

      def client_connected?(client_id)
        @mutex.synchronize { @clients.key?(client_id) }
      end

      def unregister_client(client_id)
        @mutex.synchronize do
          client = @clients.delete(client_id)
          if client
            begin
              client[:io].close
            rescue => error
              @logger.debug("Error closing SSE client connection: #{error.message}")
            end
          end
        end
        
        @logger.info("SSE client disconnected: #{client_id}")
      end

      def build_request_context(request)
        {
          remote_ip: request.ip,
          user_agent: request.user_agent,
          headers: request.env.select { |k, _| k.start_with?('HTTP_') }
        }
      end

      # Broadcast resource update to all connected clients
      def broadcast_resource_update(uri, event_type = 'resource_updated')
        return if @clients.empty?
        
        data = {
          uri: uri,
          timestamp: Time.now.iso8601
        }
        
        @clients.keys.each do |client_id|
          send_event(client_id, event_type, data)
        end
      end
    end
  end
end