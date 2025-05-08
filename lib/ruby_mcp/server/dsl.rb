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
      
      # DSL for defining resources
      # @param uri [String] The resource URI
      # @param name [String] Optional name for the resource
      # @param description [String] Optional description for the resource
      # @param mime_type [String] Optional MIME type for the resource
      # @param tags [Array<String>] Optional tags for the resource
      # @param &block [Proc] The handler block for resource content
      # @return [Resources::Resource] The created resource
      def resource(uri, name: nil, description: nil, mime_type: nil, tags: [], &block)
        ensure_resources_manager
        
        # Check if this is a template
        if uri.include?('{') && uri.include?('}')
          # Extract parameters from the URI
          params = uri.scan(/\{([^}]+)\}/).flatten
          
          # Create parameters schema
          parameters = {
            "type" => "object",
            "required" => params,
            "properties" => {}
          }
          
          # Add parameter types
          params.each do |param|
            parameters["properties"][param] = { "type" => "string" }
          end
          
          # Create a template
          template = @resources_manager.create_template(uri, parameters, name: name, description: description, tags: tags, &block)
          @resources_manager.register_template(template)
          
          template
        else
          # Create a regular resource
          resource = @resources_manager.create_resource(uri, name: name, description: description, mime_type: mime_type, tags: tags, &block)
          @resources_manager.register_resource(resource)
          
          resource
        end
      end
      
      # Register a resource on the server
      # @param resource [Resources::Resource] The resource to register
      # @param key [String] Optional key to register the resource under
      # @return [Resources::Resource] The registered resource
      def register_resource(resource, key = nil)
        ensure_resources_manager
        
        @resources_manager.register_resource(resource, key)
        resource
      end
      
      # Register a resource template on the server
      # @param template [Resources::ResourceTemplate] The template to register
      # @param key [String] Optional key to register the template under
      # @return [Resources::ResourceTemplate] The registered template
      def register_template(template, key = nil)
        ensure_resources_manager
        
        @resources_manager.register_template(template, key)
        template
      end
      
      # Get all registered resources
      # @return [Hash<String, Resources::Resource>] All registered resources
      def resources
        ensure_resources_manager
        
        @resources_manager.all_resources
      end
      
      # Get all registered templates
      # @return [Hash<String, Resources::ResourceTemplate>] All registered templates
      def templates
        ensure_resources_manager
        
        @resources_manager.all_templates
      end
      
      # DSL for defining prompts
      # @param name [String] The prompt name
      # @param description [String] Optional description for the prompt
      # @param parameters [Hash] Optional parameters schema
      # @param tags [Array<String>] Optional tags for the prompt
      # @param &block [Proc] The handler block for prompt rendering
      # @return [Prompts::Prompt] The created prompt
      def prompt(name, description: nil, parameters: nil, tags: [], &block)
        ensure_prompts_manager
        
        # Create and register the prompt
        prompt = @prompts_manager.create_prompt(name, description: description, parameters: parameters, tags: tags, &block)
        @prompts_manager.register(prompt)
        
        prompt
      end
      
      # Register a prompt on the server
      # @param prompt [Prompts::Prompt] The prompt to register
      # @param key [String] Optional key to register the prompt under
      # @return [Prompts::Prompt] The registered prompt
      def register_prompt(prompt, key = nil)
        ensure_prompts_manager
        
        @prompts_manager.register(prompt, key)
        prompt
      end
      
      # Get all registered prompts
      # @return [Hash<String, Prompts::Prompt>] All registered prompts
      def prompts
        ensure_prompts_manager
        
        @prompts_manager.all
      end
      
      # DSL for defining roots
      # @param name [String] The root name
      # @param path [String] The filesystem path
      # @param description [String] Optional description for the root
      # @param allow_writes [Boolean] Whether to allow writes to the root
      # @return [Roots::Root] The created root
      def root(name, path, description: nil, allow_writes: false)
        ensure_roots_manager
        
        # Create and register the root
        root = @roots_manager.create_root(name, path, description: description, allow_writes: allow_writes)
        @roots_manager.register(root)
        
        root
      end
      
      # Register a root on the server
      # @param root [Roots::Root] The root to register
      # @param key [String] Optional key to register the root under
      # @return [Roots::Root] The registered root
      def register_root(root, key = nil)
        ensure_roots_manager
        
        @roots_manager.register(root, key)
        root
      end
      
      # Get all registered roots
      # @return [Hash<String, Roots::Root>] All registered roots
      def roots
        ensure_roots_manager
        
        @roots_manager.all
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
      
      # Ensure the resources manager exists
      def ensure_resources_manager
        @resources_manager ||= begin
          manager = Resources::Manager.new
          manager.register_handlers(self)
          manager
        end
      end
      
      # Ensure the prompts manager exists
      def ensure_prompts_manager
        @prompts_manager ||= begin
          manager = Prompts::Manager.new
          manager.register_handlers(self)
          manager
        end
      end
      
      # Ensure the roots manager exists
      def ensure_roots_manager
        @roots_manager ||= begin
          manager = Roots::Manager.new
          manager.register_handlers(self)
          manager
        end
      end
    end
  end
end