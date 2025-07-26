# frozen_string_literal: true

module MCP
  module Server
    module Resources
      # Base resource class for MCP
      class Resource
        attr_reader :uri, :name, :description, :mime_type, :tags, :handler
        
        # Initialize a resource
        # @param uri [String] The resource URI
        # @param handler [Proc] The handler function for resource content
        # @param name [String] Optional name for the resource
        # @param description [String] Optional description for the resource
        # @param mime_type [String] Optional MIME type for the resource
        # @param tags [Array<String>] Optional tags for the resource
        def initialize(uri, handler, name: nil, description: nil, mime_type: nil, tags: [])
          @uri = uri
          @handler = handler
          @name = name || uri
          @description = description || ""
          @mime_type = mime_type || "text/plain"
          @tags = tags
        end
        
        # Convert to an MCP resource definition
        # @return [Hash] The MCP resource definition
        def to_mcp_resource
          result = {
            uri: @uri,
          }
          
          result[:name] = @name if @name
          result[:description] = @description if @description
          result[:mimeType] = @mime_type if @mime_type
          
          result
        end
        
        # Read the resource content
        # @return [String, Hash] The resource content
        def read
          @handler.call
        end
        
        # Create a resource from a Ruby method
        # @param method [Method] The method to create a resource from
        # @param uri [String] The resource URI
        # @param name [String] Optional name for the resource
        # @param description [String] Optional description for the resource
        # @param mime_type [String] Optional MIME type for the resource
        # @param tags [Array<String>] Optional tags for the resource
        # @return [Resource] The created resource
        def self.from_method(method, uri, name: nil, description: nil, mime_type: nil, tags: [])
          # Create resource handler
          handler = -> { method.call }
          
          # Create and return the resource
          new(uri, handler, name: name, description: description, mime_type: mime_type, tags: tags)
        end
      end
      
      # Resource template class for MCP
      class ResourceTemplate
        attr_reader :uri_template, :name, :description, :parameters, :tags, :handler
        
        # Initialize a resource template
        # @param uri_template [String] The resource URI template
        # @param handler [Proc] The handler function for resource content
        # @param parameters [Hash] The parameters schema
        # @param name [String] Optional name for the resource template
        # @param description [String] Optional description for the resource template
        # @param tags [Array<String>] Optional tags for the resource template
        def initialize(uri_template, handler, parameters, name: nil, description: nil, tags: [])
          @uri_template = uri_template
          @handler = handler
          @parameters = parameters
          @name = name || uri_template
          @description = description || ""
          @tags = tags
        end
        
        # Convert to an MCP resource template definition
        # @return [Hash] The MCP resource template definition
        def to_mcp_template
          result = {
            uriTemplate: @uri_template,
            parameters: @parameters
          }
          
          result[:name] = @name if @name
          result[:description] = @description if @description
          
          result
        end
        
        # Resolve the template with parameters
        # @param params [Hash] The parameters to resolve with
        # @return [String] The resolved URI
        def resolve(params)
          uri = @uri_template.dup
          
          # Replace parameters in the URI template
          params.each do |key, value|
            uri.gsub!("{#{key}}", value.to_s)
          end
          
          uri
        end
        
        # Read the resource content with parameters
        # @param params [Hash] The parameters for the resource
        # @return [String, Hash] The resource content
        def read(params)
          @handler.call(params)
        end
        
        # Create a template from a Ruby method
        # @param method [Method] The method to create a template from
        # @param uri_template [String] The resource URI template
        # @param name [String] Optional name for the template
        # @param description [String] Optional description for the template
        # @param tags [Array<String>] Optional tags for the template
        # @return [ResourceTemplate] The created template
        def self.from_method(method, uri_template, name: nil, description: nil, tags: [])
          # Get method parameters
          params = method.parameters
          required_params = params.select { |type, _| type == :req || type == :keyreq }.map { |_, name| name.to_s }
          optional_params = params.select { |type, _| type == :opt || type == :key }.map { |_, name| name.to_s }
          
          # Create parameters schema
          parameters = {
            "type" => "object",
            "required" => required_params,
            "properties" => {}
          }
          
          # Add parameter types if available
          params.each do |type, name|
            parameters["properties"][name.to_s] = { "type" => "string" }
          end
          
          # Create handler
          handler = ->(params) { method.call(*params.values_at(*params.keys)) }
          
          # Create and return the template
          new(uri_template, handler, parameters, name: name, description: description, tags: tags)
        end
      end
    end
  end
end