# frozen_string_literal: true

module MCP
  module Server
    module Prompts
      # MCP prompt class
      class Prompt
        attr_reader :name, :description, :parameters, :tags, :handler
        
        # Initialize a prompt
        # @param name [String] The prompt name
        # @param handler [Proc] The handler function for prompt rendering
        # @param parameters [Hash] Optional parameters schema
        # @param description [String] Optional description for the prompt
        # @param tags [Array<String>] Optional tags for the prompt
        def initialize(name, handler, parameters: nil, description: nil, tags: [])
          @name = name
          @handler = handler
          @parameters = parameters
          @description = description || ""
          @tags = tags
        end
        
        # Convert to an MCP prompt definition
        # @return [Hash] The MCP prompt definition
        def to_mcp_prompt
          result = {
            name: @name,
          }
          
          result[:description] = @description if @description
          result[:parameters] = @parameters if @parameters
          
          result
        end
        
        # Render the prompt
        # @param params [Hash] The parameters for the prompt
        # @return [Array<Hash>] The rendered prompt messages
        def render(params = {})
          @handler.call(params)
        end
        
        # Create a prompt from a Ruby method
        # @param method [Method] The method to create a prompt from
        # @param name [String] Optional name override
        # @param description [String] Optional description for the prompt
        # @param tags [Array<String>] Optional tags for the prompt
        # @return [Prompt] The created prompt
        def self.from_method(method, name: nil, description: nil, tags: [])
          # Get method parameters
          params = method.parameters
          required_params = params.select { |type, _| type == :req || type == :keyreq }.map { |_, name| name.to_s }
          optional_params = params.select { |type, _| type == :opt || type == :key }.map { |_, name| name.to_s }
          
          # Create parameters schema if there are any parameters
          parameters = nil
          if !params.empty?
            parameters = {
              "type" => "object",
              "required" => required_params,
              "properties" => {}
            }
            
            # Add parameter types if available
            params.each do |type, name|
              parameters["properties"][name.to_s] = { "type" => "string" }
            end
          end
          
          # Create handler
          handler = ->(params) { method.call(*params.values_at(*params.keys)) }
          
          # Create and return the prompt
          new(name || method.name, handler, parameters: parameters, description: description, tags: tags)
        end
      end
    end
  end
end