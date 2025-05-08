# frozen_string_literal: true

require 'json'
require 'json-schema'

module MCP
  module Server
    module Tools
      # Represents a tool in the MCP server
      class Tool
        attr_reader :name, :description, :input_schema, :tags, :annotations, :handler
        
        # Initialize a tool
        # @param name [String] The tool name
        # @param description [String] The tool description
        # @param input_schema [Hash] The JSON Schema for tool input parameters
        # @param handler [Proc] The handler function for tool execution
        # @param tags [Array<String>] Optional tags for the tool
        # @param annotations [Hash] Optional annotations for the tool
        def initialize(name, description, input_schema, handler, tags: [], annotations: nil)
          @name = name
          @description = description
          @input_schema = input_schema
          @handler = handler
          @tags = tags
          @annotations = annotations
        end
        
        # Convert to an MCP tool definition
        # @return [Hash] The MCP tool definition
        def to_mcp_tool
          result = {
            name: @name,
            description: @description,
            inputSchema: @input_schema
          }
          
          result[:annotations] = @annotations if @annotations
          
          result
        end
        
        # Execute the tool with the given parameters
        # @param params [Hash] The tool parameters
        # @return [Object] The tool result
        def execute(params)
          # Validate parameters against the schema
          validate_params(params)
          
          # Execute the handler
          @handler.call(params)
        end
        
        # Create a tool from a Ruby method
        # @param method [Method] The method to create a tool from
        # @param name [String] Optional name override
        # @param description [String] Optional description override
        # @param tags [Array<String>] Optional tags for the tool
        # @param annotations [Hash] Optional annotations for the tool
        # @return [Tool] The created tool
        def self.from_method(method, name: nil, description: nil, tags: [], annotations: nil)
          # Get method information
          method_name = name || method.name
          method_description = description || method.comment || ""
          
          # Generate input schema from method parameters
          params = method.parameters
          required_params = params.select { |type, _| type == :req || type == :keyreq }.map { |_, name| name.to_s }
          optional_params = params.select { |type, _| type == :opt || type == :key }.map { |_, name| name.to_s }
          
          # Create basic schema
          schema = {
            "type" => "object",
            "required" => required_params,
            "properties" => {}
          }
          
          # Add parameter types if available (requires method annotations)
          # This is a simplified version, in a real implementation you'd use Ruby's reflection capabilities
          params.each do |type, name|
            schema["properties"][name.to_s] = { "type" => "string" }
          end
          
          # Create tool handler
          handler = ->(params) { method.call(*params.values_at(*method.parameters.map { |_, name| name })) }
          
          # Create and return the tool
          new(method_name, method_description, schema, handler, tags: tags, annotations: annotations)
        end
        
        private
        
        # Validate parameters against the schema
        # @param params [Hash] The parameters to validate
        # @raise [MCP::Errors::ToolError] If the parameters are invalid
        def validate_params(params)
          begin
            JSON::Validator.validate!(@input_schema, params)
          rescue JSON::Schema::ValidationError => e
            raise MCP::Errors::ToolError, "Invalid parameters: #{e.message}"
          end
        end
      end
    end
  end
end