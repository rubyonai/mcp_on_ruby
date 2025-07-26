# frozen_string_literal: true

module MCP
  module Server
    module Resources
      # Manages resources for the MCP server
      class Manager
        def initialize
          @resources = {}
          @templates = {}
          @logger = MCP.logger
        end
        
        # Register a resource
        # @param resource [Resource] The resource to register
        # @param key [String] Optional key to register the resource under
        # @raise [MCP::Errors::ResourceError] If a resource with the same key already exists
        def register_resource(resource, key = nil)
          key ||= resource.uri
          
          if @resources.key?(key)
            raise MCP::Errors::ResourceError, "Resource with key '#{key}' already exists"
          end
          
          @resources[key] = resource
          @logger.debug("Registered resource: #{key}")
        end
        
        # Register a resource template
        # @param template [ResourceTemplate] The template to register
        # @param key [String] Optional key to register the template under
        # @raise [MCP::Errors::ResourceError] If a template with the same key already exists
        def register_template(template, key = nil)
          key ||= template.uri_template
          
          if @templates.key?(key)
            raise MCP::Errors::ResourceError, "Template with key '#{key}' already exists"
          end
          
          @templates[key] = template
          @logger.debug("Registered template: #{key}")
        end
        
        # Get a resource by key
        # @param key [String] The key of the resource to get
        # @return [Resource, nil] The resource, or nil if not found
        def get_resource(key)
          @resources[key]
        end
        
        # Get a template by key
        # @param key [String] The key of the template to get
        # @return [ResourceTemplate, nil] The template, or nil if not found
        def get_template(key)
          @templates[key]
        end
        
        # Get all registered resources
        # @return [Hash<String, Resource>] All registered resources
        def all_resources
          @resources
        end
        
        # Get all registered templates
        # @return [Hash<String, ResourceTemplate>] All registered templates
        def all_templates
          @templates
        end
        
        # Read a resource's content
        # @param uri [String] The URI of the resource to read
        # @param params [Hash] Optional parameters for template resources
        # @return [String, Hash] The resource content
        # @raise [MCP::Errors::ResourceError] If the resource does not exist
        def read(uri, params = nil)
          # Check if this is a direct resource
          if resource = @resources[uri]
            return resource.read
          end
          
          # Check if this is a template resource
          @templates.each do |key, template|
            # This is a very simple match, in a real implementation you'd use a proper URI template parser
            if uri.include?('{') && uri.include?('}')
              if params
                resolved_uri = template.resolve(params)
                if resolved_uri == uri
                  return template.read(params)
                end
              end
            end
          end
          
          raise MCP::Errors::ResourceError, "Resource not found: #{uri}"
        end
        
        # Create a resource from a block
        # @param uri [String] The resource URI
        # @param name [String] Optional name for the resource
        # @param description [String] Optional description for the resource
        # @param mime_type [String] Optional MIME type for the resource
        # @param tags [Array<String>] Optional tags for the resource
        # @param &block [Proc] The handler block for resource content
        # @return [Resource] The created resource
        def create_resource(uri, name: nil, description: nil, mime_type: nil, tags: [], &block)
          Resource.new(uri, block, name: name, description: description, mime_type: mime_type, tags: tags)
        end
        
        # Create a template from a block
        # @param uri_template [String] The resource URI template
        # @param parameters [Hash] The parameters schema
        # @param name [String] Optional name for the template
        # @param description [String] Optional description for the template
        # @param tags [Array<String>] Optional tags for the template
        # @param &block [Proc] The handler block for resource content
        # @return [ResourceTemplate] The created template
        def create_template(uri_template, parameters, name: nil, description: nil, tags: [], &block)
          ResourceTemplate.new(uri_template, block, parameters, name: name, description: description, tags: tags)
        end
        
        # Register resource handlers on the server
        # @param server [MCP::Server::Server] The server to register the handlers on
        def register_handlers(server)
          # Register resources/list method handler
          server.on_method('resources/list') do |_params|
            handle_list_resources
          end
          
          # Register resources/listResourceTemplates method handler
          server.on_method('resources/listResourceTemplates') do |_params|
            handle_list_templates
          end
          
          # Register resources/read method handler
          server.on_method('resources/read') do |params|
            handle_read(params)
          end
        end
        
        private
        
        # Handle resources/list method
        # @return [Hash] The response
        def handle_list_resources
          {
            resources: @resources.values.map(&:to_mcp_resource)
          }
        end
        
        # Handle resources/listResourceTemplates method
        # @return [Hash] The response
        def handle_list_templates
          {
            resourceTemplates: @templates.values.map(&:to_mcp_template)
          }
        end
        
        # Handle resources/read method
        # @param params [Hash] The method parameters
        # @return [Hash] The response
        def handle_read(params)
          begin
            uri = params[:uri]
            template_params = params[:params]
            
            # Read the resource content
            content = read(uri, template_params)
            
            # Convert to MCP format
            if content.is_a?(String)
              mime_type = @resources[uri]&.mime_type || 'text/plain'
              {
                contents: [
                  {
                    content: content,
                    mime_type: mime_type
                  }
                ]
              }
            else
              # Assume it's already in MCP format
              { contents: content }
            end
          rescue MCP::Errors::ResourceError => e
            raise e
          rescue => e
            @logger.error("Error reading resource #{uri}: #{e.message}")
            raise MCP::Errors::ResourceError, "Error reading resource: #{e.message}"
          end
        end
      end
    end
  end
end