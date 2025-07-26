# frozen_string_literal: true

module McpOnRuby
  # Main MCP server class that handles JSON-RPC protocol and manages tools/resources
  class Server
    attr_reader :tools, :resources, :configuration, :logger

    # Initialize a new MCP server
    # @param options [Hash] Server configuration options
    # @yield [Server] Server instance for configuration
    def initialize(options = {}, &block)
      @configuration = McpOnRuby.configuration || Configuration.new
      @configuration.tap do |config|
        options.each { |key, value| config.send("#{key}=", value) if config.respond_to?("#{key}=") }
      end
      
      @logger = McpOnRuby.logger
      @tools = {}
      @resources = {}
      @rate_limiter = RateLimiter.new(@configuration.rate_limit_per_minute)
      
      # Configure the server using the block
      instance_eval(&block) if block_given?
    end

    # Register a tool
    # @param tool [Tool] The tool to register
    # @param name [String] Optional name override
    # @return [Tool] The registered tool
    def register_tool(tool, name = nil)
      tool_name = name || tool.name
      @tools[tool_name] = tool
      @logger.debug("Registered tool: #{tool_name}")
      tool
    end

    # Register a resource
    # @param resource [Resource] The resource to register
    # @param uri [String] Optional URI override
    # @return [Resource] The registered resource
    def register_resource(resource, uri = nil)
      resource_uri = uri || resource.uri
      @resources[resource_uri] = resource
      @logger.debug("Registered resource: #{resource_uri}")
      resource
    end

    # DSL method to define a tool
    # @param name [String] Tool name
    # @param description [String] Tool description
    # @param input_schema [Hash] JSON Schema for validation
    # @param options [Hash] Additional options (metadata, tags)
    # @param block [Proc] Tool implementation
    # @return [Tool] The created and registered tool
    def tool(name, description = '', input_schema = {}, **options, &block)
      tool_instance = McpOnRuby.tool(name, description, input_schema, **options, &block)
      register_tool(tool_instance)
    end

    # DSL method to define a resource
    # @param uri [String] Resource URI
    # @param options [Hash] Resource options (name, description, etc.)
    # @param block [Proc] Resource implementation
    # @return [Resource] The created and registered resource
    def resource(uri, **options, &block)
      resource_instance = McpOnRuby.resource(uri, **options, &block)
      register_resource(resource_instance)
    end

    # Handle a JSON-RPC request
    # @param request_body [String] JSON request body
    # @param context [Hash] Request context (headers, IP, etc.)
    # @return [String, nil] JSON response or nil for notifications
    def handle_request(request_body, context = {})
      # Parse JSON request
      request = JSON.parse(request_body)
      
      # Rate limiting check
      unless @rate_limiter.allowed?(context[:remote_ip])
        return error_response(nil, -32603, "Rate limit exceeded")
      end
      
      # Handle the request
      response = handle_json_rpc(request, context)
      
      # Return JSON response for requests with ID, nil for notifications
      response ? JSON.generate(response) : nil
      
    rescue JSON::ParserError => e
      @logger.warn("Invalid JSON request: #{e.message}")
      JSON.generate(error_response(nil, -32700, "Parse error"))
    rescue => e
      @logger.error("Request handling failed: #{e.message}")
      @logger.error(e.backtrace.join("\n"))
      JSON.generate(error_response(nil, -32603, "Internal error"))
    end

    # Get server capabilities for MCP initialization
    # @return [Hash] Server capabilities
    def capabilities
      {
        tools: tools.any? ? {} : nil,
        resources: resources.any? ? { subscribe: @configuration.enable_sse } : nil
      }.compact
    end

    # Get server information
    # @return [Hash] Server info
    def server_info
      {
        name: "mcp_on_ruby",
        version: McpOnRuby::VERSION
      }
    end

    private

    # Handle JSON-RPC protocol
    # @param request [Hash] Parsed JSON-RPC request
    # @param context [Hash] Request context
    # @return [Hash, nil] Response hash or nil for notifications
    def handle_json_rpc(request, context)
      method = request['method']
      params = request['params'] || {}
      id = request['id']
      
      @logger.debug("Handling method: #{method}")
      
      case method
      when 'initialize'
        success_response(id, handle_initialize(params))
      when 'tools/list'
        success_response(id, handle_tools_list(context))
      when 'tools/call'
        success_response(id, handle_tool_call(params, context))
      when 'resources/list'
        success_response(id, handle_resources_list(context))
      when 'resources/read'
        success_response(id, handle_resource_read(params, context))
      when 'ping'
        success_response(id, { pong: true })
      else
        id ? error_response(id, -32601, "Method not found: #{method}") : nil
      end
    end

    # Handle initialization request
    # @param params [Hash] Initialization parameters
    # @return [Hash] Initialization response
    def handle_initialize(params)
      client_info = params['clientInfo'] || {}
      protocol_version = params['protocolVersion']
      
      @logger.info("Client connected: #{client_info['name']} #{client_info['version']}")
      
      {
        serverInfo: server_info,
        protocolVersion: McpOnRuby::PROTOCOL_VERSION,
        capabilities: capabilities
      }
    end

    # Handle tools list request
    # @param context [Hash] Request context
    # @return [Hash] Tools list response
    def handle_tools_list(context)
      authorized_tools = @tools.select { |_, tool| tool.authorized?(context) }
      
      {
        tools: authorized_tools.values.map(&:to_schema)
      }
    end

    # Handle tool call request
    # @param params [Hash] Tool call parameters
    # @param context [Hash] Request context
    # @return [Hash] Tool call response
    def handle_tool_call(params, context)
      tool_name = params['name']
      arguments = params['arguments'] || {}
      
      tool = @tools[tool_name]
      unless tool
        raise McpOnRuby::NotFoundError, "Tool not found: #{tool_name}"
      end
      
      unless tool.authorized?(context)
        raise McpOnRuby::AuthorizationError, "Not authorized to call tool: #{tool_name}"
      end
      
      result = tool.call(arguments, context)
      
      # Handle error results from tool execution
      if result.key?(:error)
        raise McpOnRuby::ToolExecutionError, result[:error][:message]
      end
      
      {
        content: [
          {
            type: "text",
            text: serialize_tool_result(result)
          }
        ]
      }
    end

    # Handle resources list request
    # @param context [Hash] Request context
    # @return [Hash] Resources list response
    def handle_resources_list(context)
      authorized_resources = @resources.select { |_, resource| resource.authorized?(context) }
      
      {
        resources: authorized_resources.values.map(&:to_schema)
      }
    end

    # Handle resource read request
    # @param params [Hash] Resource read parameters
    # @param context [Hash] Request context
    # @return [Hash] Resource read response
    def handle_resource_read(params, context)
      uri = params['uri']
      
      # Find exact match or template match
      resource = find_resource(uri)
      unless resource
        raise McpOnRuby::NotFoundError, "Resource not found: #{uri}"
      end
      
      unless resource.authorized?(context)
        raise McpOnRuby::AuthorizationError, "Not authorized to read resource: #{uri}"
      end
      
      # Extract parameters from URI if it's a template
      template_params = extract_template_params(resource.uri, uri)
      
      result = resource.read(template_params, context)
      
      # Handle error results from resource reading
      if result.key?(:error)
        raise McpOnRuby::ResourceReadError, result[:error][:message]
      end
      
      result
    end

    # Find a resource by URI (exact match or template match)
    # @param uri [String] The URI to find
    # @return [Resource, nil] The matching resource
    def find_resource(uri)
      # Try exact match first
      return @resources[uri] if @resources.key?(uri)
      
      # Try template matching
      @resources.each do |template_uri, resource|
        next unless resource.template?
        
        if uri_matches_template?(template_uri, uri)
          return resource
        end
      end
      
      nil
    end

    # Check if a URI matches a template
    # @param template [String] Template URI with {param} placeholders
    # @param uri [String] Actual URI to match
    # @return [Boolean] True if URI matches template
    def uri_matches_template?(template, uri)
      # Convert template to regex
      regex_pattern = template.gsub(/\{[^}]+\}/, '([^/]+)')
      regex = /^#{regex_pattern}$/
      
      uri =~ regex
    end

    # Extract parameters from URI using template
    # @param template [String] Template URI
    # @param uri [String] Actual URI
    # @return [Hash] Extracted parameters
    def extract_template_params(template, uri)
      return {} unless template.include?('{')
      
      # Get parameter names
      param_names = template.scan(/\{([^}]+)\}/).flatten
      
      # Convert template to regex with capture groups
      regex_pattern = template.gsub(/\{[^}]+\}/, '([^/]+)')
      regex = /^#{regex_pattern}$/
      
      # Extract values
      matches = uri.match(regex)
      return {} unless matches
      
      # Build parameter hash
      param_names.zip(matches.captures).to_h
    end

    # Serialize tool result for response
    # @param result [Object] Tool execution result
    # @return [String] Serialized result
    def serialize_tool_result(result)
      case result
      when String
        result
      when Hash, Array
        JSON.pretty_generate(result)
      else
        result.to_s
      end
    end

    # Create success response
    # @param id [String, Integer] Request ID
    # @param result [Object] Response result
    # @return [Hash] Success response
    def success_response(id, result)
      {
        jsonrpc: "2.0",
        id: id,
        result: result
      }
    end

    # Create error response
    # @param id [String, Integer, nil] Request ID
    # @param code [Integer] Error code
    # @param message [String] Error message
    # @param data [Object] Additional error data
    # @return [Hash] Error response
    def error_response(id, code, message, data = nil)
      response = {
        jsonrpc: "2.0",
        id: id,
        error: {
          code: code,
          message: message
        }
      }
      response[:error][:data] = data if data
      response
    end

    # Simple rate limiter
    class RateLimiter
      def initialize(requests_per_minute)
        @requests_per_minute = requests_per_minute
        @requests = {}
        @mutex = Mutex.new
      end

      def allowed?(ip)
        return true if @requests_per_minute <= 0
        
        @mutex.synchronize do
          now = Time.now.to_i
          minute = now / 60
          
          @requests[ip] ||= {}
          @requests[ip][minute] ||= 0
          
          # Clean old entries
          @requests[ip].delete_if { |m, _| m < minute }
          
          if @requests[ip][minute] >= @requests_per_minute
            false
          else
            @requests[ip][minute] += 1
            true
          end
        end
      end
    end
  end
end