# frozen_string_literal: true

module MCP
  module Protocol
    module Types
      # Base class for all MCP message types
      class Message
        attr_reader :type

        def initialize(type)
          @type = type
        end

        def to_h
          { type: @type }
        end
      end

      # Text content type
      class TextContent < Message
        attr_reader :text

        def initialize(text)
          super('text')
          @text = text
        end

        def to_h
          super.merge(text: @text)
        end
      end

      # Image content type
      class ImageContent < Message
        attr_reader :url, :mime_type, :width, :height

        def initialize(url, mime_type, width = nil, height = nil)
          super('image')
          @url = url
          @mime_type = mime_type
          @width = width
          @height = height
        end

        def to_h
          result = super.merge(url: @url, mime_type: @mime_type)
          result[:width] = @width if @width
          result[:height] = @height if @height
          result
        end
      end

      # Resource reference type
      class ResourceReference < Message
        attr_reader :uri, :text

        def initialize(uri, text = nil)
          super('resource')
          @uri = uri
          @text = text
        end

        def to_h
          result = super.merge(resource: { uri: @uri })
          result[:resource][:text] = @text if @text
          result
        end
      end

      # Embedded resource type
      class EmbeddedResource < Message
        attr_reader :resource

        def initialize(resource)
          super('resource')
          @resource = resource
        end

        def to_h
          super.merge(resource: @resource)
        end
      end

      # Tool type for MCP
      class Tool
        attr_reader :name, :description, :input_schema, :annotations

        def initialize(name, description, input_schema, annotations = nil)
          @name = name
          @description = description
          @input_schema = input_schema
          @annotations = annotations
        end

        def to_h
          result = {
            name: @name,
            description: @description,
            inputSchema: @input_schema
          }
          result[:annotations] = @annotations if @annotations
          result
        end
      end

      # Resource type for MCP
      class Resource
        attr_reader :uri, :name, :description, :mime_type

        def initialize(uri, name = nil, description = nil, mime_type = nil)
          @uri = uri
          @name = name
          @description = description
          @mime_type = mime_type
        end

        def to_h
          result = { uri: @uri }
          result[:name] = @name if @name
          result[:description] = @description if @description
          result[:mimeType] = @mime_type if @mime_type
          result
        end
      end

      # ResourceTemplate type for MCP
      class ResourceTemplate
        attr_reader :uri_template, :name, :description, :parameters

        def initialize(uri_template, name = nil, description = nil, parameters = nil)
          @uri_template = uri_template
          @name = name
          @description = description
          @parameters = parameters
        end

        def to_h
          result = { uriTemplate: @uri_template }
          result[:name] = @name if @name
          result[:description] = @description if @description
          result[:parameters] = @parameters if @parameters
          result
        end
      end

      # Prompt type for MCP
      class Prompt
        attr_reader :name, :description, :parameters

        def initialize(name, description = nil, parameters = nil)
          @name = name
          @description = description
          @parameters = parameters
        end

        def to_h
          result = { name: @name }
          result[:description] = @description if @description
          result[:parameters] = @parameters if @parameters
          result
        end
      end
    end
  end
end