# frozen_string_literal: true

module MCP
  module Server
    # DSL for the MCP server
    module DSL
      # DSL for defining tools
      # @param name [String] The tool name
      # @param description [String] The tool description
      # @param input_schema [Hash] The JSON Schema for tool input parameters
      # @param tags [Array<String>] Optional tags for the tool
      # @param annotations [Hash] Optional annotations for the tool
      # @param &block [Proc] The handler block for tool execution
      # @return [Tools::Tool] The created tool
      def tool(name, description = '', input_schema = {}, tags: [], annotations: nil, &block)
        ensure_tools_manager
        
        # Create and register the tool
        tool = @tools_manager.create_tool(name, description, input_schema, tags: tags, annotations: annotations, &block)
        @tools_manager.register(tool)
        
        tool
      end
      
      # Register a tool on the server
      # @param tool [Tools::Tool] The tool to register
      # @param key [String] Optional key to register the tool under
      # @return [Tools::Tool] The registered tool
      def register_tool(tool, key = nil)
        ensure_tools_manager
        
        @tools_manager.register(tool, key)
        tool
      end
      
      # Get a tool by key
      # @param key [String] The key of the tool to get
      # @return [Tools::Tool, nil] The tool, or nil if not found
      def get_tool(key)
        ensure_tools_manager
        
        @tools_manager.get(key)
      end
      
      # Get all registered tools
      # @return [Hash<String, Tools::Tool>] All registered tools
      def tools
        ensure_tools_manager
        
        @tools_manager.all
      end
      
      private
      
      # Ensure the tools manager exists
      def ensure_tools_manager
        @tools_manager ||= begin
          manager = Tools::Manager.new
          manager.register_handlers(self)
          manager
        end
      end
    end
  end
end