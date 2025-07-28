# frozen_string_literal: true

module McpOnRuby
  # Base class for MCP resources - data sources that AI can read
  class Resource
    attr_reader :uri, :name, :description, :mime_type, :metadata, :tags

    # Create a new resource
    # @param uri [String] The resource URI (supports templates with {param})
    # @param name [String] Optional human-readable name
    # @param description [String] Resource description
    # @param mime_type [String] MIME type of the resource content
    # @param metadata [Hash] Additional metadata
    # @param tags [Array<String>] Tags for categorization
    def initialize(uri:, name: nil, description: '', mime_type: 'application/json', metadata: {}, tags: [])
      @uri = uri.to_s
      @name = name
      @description = description
      @mime_type = mime_type
      @metadata = metadata
      @tags = Array(tags)
    end

    # Read the resource content with given parameters
    # @param params [Hash] URI template parameters
    # @param context [Hash] Request context (headers, user info, etc.)
    # @return [Hash] The resource content wrapped in MCP format
    def read(params = {}, context = {})
      # Validate parameters if this is a template
      validate_template_params!(params) if template?
      
      # Get the content
      content = fetch_content(params, context)
      
      # Wrap in MCP resource format
      {
        contents: [
          {
            uri: resolve_uri(params),
            mimeType: mime_type,
            text: serialize_content(content)
          }
        ]
      }
    rescue => error
      McpOnRuby.logger.error("Resource '#{uri}' read failed: #{error.message}")
      McpOnRuby.logger.error(error.backtrace.join("\n"))
      
      {
        error: {
          code: -32603,
          message: "Resource read failed: #{error.message}",
          data: { uri: uri, error_type: error.class.name }
        }
      }
    end

    # Get the resource schema for MCP protocol
    # @return [Hash] The resource schema
    def to_schema
      schema = {
        uri: uri,
        mimeType: mime_type
      }
      
      schema[:name] = name if name
      schema[:description] = description unless description.empty?
      schema[:metadata] = metadata unless metadata.empty?
      schema[:tags] = tags unless tags.empty?
      
      schema
    end

    # Check if this resource is a template (contains {param} placeholders)
    # @return [Boolean] True if resource URI contains template parameters
    def template?
      uri.include?('{') && uri.include?('}')
    end

    # Extract parameter names from template URI
    # @return [Array<String>] Parameter names
    def template_params
      return [] unless template?
      
      uri.scan(/\{([^}]+)\}/).flatten
    end

    # Check if resource is authorized for the given context
    # @param context [Hash] Request context
    # @return [Boolean] True if authorized
    def authorized?(context = {})
      return true unless respond_to?(:authorize, true)
      
      authorize(context)
    rescue => error
      McpOnRuby.logger.warn("Authorization check failed for resource '#{uri}': #{error.message}")
      false
    end

    protected

    # Override this method to implement resource content fetching
    # @param params [Hash] URI template parameters
    # @param context [Hash] Request context
    # @return [Object] Resource content (will be serialized)
    def fetch_content(params, context)
      raise NotImplementedError, "Resource '#{uri}' must implement #fetch_content method"
    end

    # Override this method to implement authorization logic
    # @param context [Hash] Request context
    # @return [Boolean] True if authorized
    def authorize(context)
      true
    end

    private

    # Validate template parameters
    # @param params [Hash] Parameters to validate
    # @raise [McpOnRuby::ValidationError] If required parameters are missing
    def validate_template_params!(params)
      required_params = template_params
      missing_params = required_params - params.keys.map(&:to_s)
      
      unless missing_params.empty?
        raise McpOnRuby::ValidationError, 
              "Resource '#{uri}' missing required parameters: #{missing_params.join(', ')}"
      end
    end

    # Resolve URI template with parameters
    # @param params [Hash] Parameters to substitute
    # @return [String] Resolved URI
    def resolve_uri(params)
      return uri unless template?
      
      resolved = uri.dup
      params.each do |key, value|
        resolved.gsub!("{#{key}}", value.to_s)
      end
      resolved
    end

    # Serialize content based on MIME type
    # @param content [Object] Content to serialize
    # @return [String] Serialized content
    def serialize_content(content)
      case mime_type
      when 'application/json'
        content.is_a?(String) ? content : JSON.pretty_generate(content)
      when 'text/plain', 'text/html', 'text/css', 'text/javascript'
        content.to_s
      else
        # For other types, assume it's already in the correct format
        content.to_s
      end
    end
  end

end