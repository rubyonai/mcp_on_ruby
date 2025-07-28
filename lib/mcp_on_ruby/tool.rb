# frozen_string_literal: true

module McpOnRuby
  # Base class for MCP tools - functions that AI can execute
  class Tool
    attr_reader :name, :description, :input_schema, :metadata, :tags

    # Create a new tool
    # @param name [String] The tool name
    # @param description [String] The tool description
    # @param input_schema [Hash] JSON Schema for input validation
    # @param metadata [Hash] Additional metadata
    # @param tags [Array<String>] Tags for categorization
    def initialize(name:, description: '', input_schema: {}, metadata: {}, tags: [])
      @name = name.to_s
      @description = description
      @input_schema = normalize_schema(input_schema)
      @metadata = metadata
      @tags = Array(tags)
    end

    # Execute the tool with given arguments
    # @param arguments [Hash] The arguments to pass to the tool
    # @param context [Hash] Request context (headers, user info, etc.)
    # @return [Hash] The tool execution result
    def call(arguments = {}, context = {})
      # Validate arguments against schema
      validate_arguments!(arguments)
      
      # Call the implementation
      execute(arguments, context)
    rescue => error
      McpOnRuby.logger.error("Tool '#{name}' execution failed: #{error.message}")
      McpOnRuby.logger.error(error.backtrace.join("\n"))
      
      {
        error: {
          code: -32603,
          message: "Tool execution failed: #{error.message}",
          data: { tool: name, error_type: error.class.name }
        }
      }
    end

    # Get the tool's schema for MCP protocol
    # @return [Hash] The tool schema
    def to_schema
      {
        name: name,
        description: description,
        inputSchema: input_schema
      }.tap do |schema|
        schema[:metadata] = metadata unless metadata.empty?
        schema[:tags] = tags unless tags.empty?
      end
    end

    # Check if tool is authorized for the given context
    # @param context [Hash] Request context
    # @return [Boolean] True if authorized
    def authorized?(context = {})
      return true unless respond_to?(:authorize, true)
      
      authorize(context)
    rescue => error
      McpOnRuby.logger.warn("Authorization check failed for tool '#{name}': #{error.message}")
      false
    end

    protected

    # Override this method to implement tool functionality
    # @param arguments [Hash] Validated arguments
    # @param context [Hash] Request context
    # @return [Hash] Tool result
    def execute(arguments, context)
      raise NotImplementedError, "Tool '#{name}' must implement #execute method"
    end

    # Override this method to implement authorization logic
    # @param context [Hash] Request context
    # @return [Boolean] True if authorized
    def authorize(context)
      true
    end

    private

    # Validate arguments against the input schema
    # @param arguments [Hash] Arguments to validate
    # @raise [McpOnRuby::ValidationError] If validation fails
    def validate_arguments!(arguments)
      return if input_schema.empty?

      errors = JSON::Validator.fully_validate(input_schema, arguments)
      return if errors.empty?

      raise McpOnRuby::ValidationError, "Tool '#{name}' validation failed: #{errors.join(', ')}"
    end

    # Normalize schema to ensure it's a proper JSON Schema
    # @param schema [Hash] Input schema
    # @return [Hash] Normalized schema
    def normalize_schema(schema)
      return {} if schema.nil? || schema.empty?

      # Ensure we have a proper JSON Schema structure
      normalized = schema.is_a?(Hash) ? schema.dup : {}
      
      # Set default type if not specified
      normalized['type'] ||= 'object' if normalized.key?('properties') || normalized.key?('required')
      
      # Convert symbol keys to strings for JSON Schema compatibility
      deep_stringify_keys(normalized)
    end

    # Convert all symbol keys to strings recursively
    # @param obj [Object] Object to convert
    # @return [Object] Object with string keys
    def deep_stringify_keys(obj)
      case obj
      when Hash
        obj.each_with_object({}) do |(key, value), hash|
          hash[key.to_s] = deep_stringify_keys(value)
        end
      when Array
        obj.map { |item| deep_stringify_keys(item) }
      else
        obj
      end
    end
  end

end