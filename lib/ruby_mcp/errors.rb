# frozen_string_literal: true

module MCP
  module Errors
    # Base error class for all MCP errors
    class Error < StandardError; end

    # Protocol errors
    class ProtocolError < Error; end
    
    # JSON-RPC protocol error
    class JsonRpcError < ProtocolError
      attr_reader :code, :data
      
      def initialize(message, code, data = nil)
        super(message)
        @code = code
        @data = data
      end
    end
    
    # Parsing error
    class ParseError < JsonRpcError
      def initialize(message = 'Parse error', data = nil)
        super(message, -32700, data)
      end
    end
    
    # Invalid request error
    class InvalidRequestError < JsonRpcError
      def initialize(message = 'Invalid request', data = nil)
        super(message, -32600, data)
      end
    end
    
    # Method not found error
    class MethodNotFoundError < JsonRpcError
      def initialize(message = 'Method not found', data = nil)
        super(message, -32601, data)
      end
    end
    
    # Invalid params error
    class InvalidParamsError < JsonRpcError
      def initialize(message = 'Invalid params', data = nil)
        super(message, -32602, data)
      end
    end
    
    # Internal error
    class InternalError < JsonRpcError
      def initialize(message = 'Internal error', data = nil)
        super(message, -32603, data)
      end
    end
    
    # Transport errors
    class TransportError < ProtocolError; end
    
    # Connection error
    class ConnectionError < TransportError; end
    
    # Timeout error
    class TimeoutError < TransportError; end

    # Server errors
    class ServerError < Error; end
    
    # Tool error
    class ToolError < ServerError; end
    
    # Resource error
    class ResourceError < ServerError; end
    
    # Prompt error
    class PromptError < ServerError; end
    
    # Root error
    class RootError < ServerError; end

    # Client errors
    class ClientError < Error; end
    
    # Authentication error
    class AuthenticationError < ClientError; end
    
    # Authorization error
    class AuthorizationError < ClientError; end
  end
end