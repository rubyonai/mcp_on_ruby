# frozen_string_literal: true

module MCP
  module Server
    module Tools
      # Manages tools for the MCP server
      class Manager
        def initialize
          @tools = {}
          @logger = MCP.logger
        end
        
        # Register a tool
        # @param tool [Tool] The tool to register
        # @param key [String] Optional key to register the tool under
        # @raise [MCP::Errors::ToolError] If a tool with the same key already exists
        def register(tool, key = nil)
          key ||= tool.name
          
          if @tools.key?(key)
            raise MCP::Errors::ToolError, "Tool with key '#{key}' already exists"
          end
          
          @tools[key] = tool
          @logger.debug("Registered tool: #{key}")
        end
        
        # Unregister a tool
        # @param key [String] The key of the tool to unregister
        # @return [Tool, nil] The unregistered tool, or nil if not found
        def unregister(key)
          tool = @tools.delete(key)
          @logger.debug("Unregistered tool: #{key}") if tool
          tool
        end
        
        # Get a tool by key
        # @param key [String] The key of the tool to get
        # @return [Tool, nil] The tool, or nil if not found
        def get(key)
          @tools[key]
        end
        
        # Check if a tool exists
        # @param key [String] The key of the tool to check
        # @return [Boolean] true if the tool exists
        def exists?(key)
          @tools.key?(key)
        end
        
        # Get all registered tools
        # @return [Hash<String, Tool>] All registered tools
        def all
          @tools
        end
        
        # Execute a tool with the given parameters
        # @param key [String] The key of the tool to execute
        # @param params [Hash] The tool parameters
        # @return [Object] The tool result
        # @raise [MCP::Errors::ToolError] If the tool does not exist
        def execute(key, params)
          tool = get(key)
          
          if tool.nil?
            raise MCP::Errors::ToolError, "Tool not found: #{key}"
          end
          
          begin
            tool.execute(params)
          rescue => e
            @logger.error("Error executing tool '#{key}': #{e.message}")
            raise MCP::Errors::ToolError, "Error executing tool '#{key}': #{e.message}"
          end
        end
        
        # Create a tool from a block
        # @param name [String] The tool name
        # @param description [String] The tool description
        # @param input_schema [Hash] The JSON Schema for tool input parameters
        # @param tags [Array<String>] Optional tags for the tool
        # @param annotations [Hash] Optional annotations for the tool
        # @param &block [Proc] The handler block for tool execution
        # @return [Tool] The created tool
        def create_tool(name, description, input_schema, tags: [], annotations: nil, &block)
          Tool.new(name, description, input_schema, block, tags: tags, annotations: annotations)
        end
        
        # Register a tool handler on the server
        # @param server [MCP::Server::Server] The server to register the handler on
        def register_handlers(server)
          # Register tools/list method handler
          server.on_method('tools/list') do |_params|
            handle_list
          end
          
          # Register tools/call method handler
          server.on_method('tools/call') do |params|
            handle_call(params)
          end
        end
        
        private
        
        # Handle tools/list method
        # @return [Hash] The response
        def handle_list
          {
            tools: @tools.values.map(&:to_mcp_tool)
          }
        end
        
        # Handle tools/call method
        # @param params [Hash] The method parameters
        # @return [Hash] The response
        def handle_call(params)
          begin
            name = params[:name]
            arguments = params[:arguments] || {}
            
            # Execute the tool
            result = execute(name, arguments)
            
            # Convert to MCP content format
            # This is a simplified conversion, in a real implementation you'd handle complex types
            content = []
            
            if result.is_a?(Array)
              content = result.map { |item| convert_to_content(item) }.flatten
            else
              content << convert_to_content(result)
            end
            
            {
              content: content,
              isError: false
            }
          rescue MCP::Errors::ToolError => e
            {
              content: [{ type: 'text', text: e.message }],
              isError: true
            }
          end
        end
        
        # Convert a result to MCP content format
        # @param result [Object] The result to convert
        # @return [Hash] The MCP content
        def convert_to_content(result)
          case result
          when Hash
            if result[:type] && (result[:type] == 'text' || result[:type] == 'image')
              # Already in MCP content format
              result
            else
              # Convert to JSON
              { type: 'text', text: JSON.generate(result) }
            end
          when String
            { type: 'text', text: result }
          else
            # Convert to JSON
            { type: 'text', text: JSON.generate(result) }
          end
        end
      end
    end
  end
end