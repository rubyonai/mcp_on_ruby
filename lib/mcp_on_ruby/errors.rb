# frozen_string_literal: true

module McpOnRuby
  # Base error class for MCP-related errors
  class Error < StandardError
    attr_reader :code, :data

    def initialize(message, code: nil, data: nil)
      super(message)
      @code = code
      @data = data
    end

    # Convert error to JSON-RPC error format
    def to_json_rpc
      {
        code: @code || default_error_code,
        message: message,
        data: @data
      }.compact
    end

    private

    def default_error_code
      -32603 # Internal error
    end
  end

  # JSON-RPC parsing error
  class ParseError < Error
    private

    def default_error_code
      -32700
    end
  end

  # Invalid JSON-RPC request
  class InvalidRequestError < Error
    private

    def default_error_code
      -32600
    end
  end

  # Method not found
  class MethodNotFoundError < Error
    private

    def default_error_code
      -32601
    end
  end

  # Invalid method parameters
  class InvalidParamsError < Error
    private

    def default_error_code
      -32602
    end
  end

  # Tool or resource not found
  class NotFoundError < Error
    private

    def default_error_code
      -32603
    end
  end

  # Authorization/authentication failed
  class AuthorizationError < Error
    private

    def default_error_code
      -32600
    end
  end

  # Validation error for tool arguments or resource parameters
  class ValidationError < Error
    private

    def default_error_code
      -32602
    end
  end

  # Tool execution error
  class ToolExecutionError < Error
    private

    def default_error_code
      -32603
    end
  end

  # Resource read error
  class ResourceReadError < Error
    private

    def default_error_code
      -32603
    end
  end

  # Rate limiting error
  class RateLimitError < Error
    private

    def default_error_code
      -32603
    end
  end

  # Configuration error
  class ConfigurationError < Error
    private

    def default_error_code
      -32603
    end
  end

  # Transport error
  class TransportError < Error
    private

    def default_error_code
      -32603
    end
  end
end