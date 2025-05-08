# frozen_string_literal: true

module RubyMCP
  module Errors
    # Base error class for all RubyMCP errors
    class Error < StandardError; end

    # Protocol errors
    class ProtocolError < Error; end
    class TransportError < ProtocolError; end
    class InvalidRequestError < ProtocolError; end
    class MethodNotFoundError < ProtocolError; end

    # Server errors
    class ServerError < Error; end
    class ToolError < ServerError; end
    class ResourceError < ServerError; end
    class PromptError < ServerError; end
    class RootError < ServerError; end

    # Client errors
    class ClientError < Error; end
    class ConnectionError < ClientError; end
    class AuthenticationError < ClientError; end
  end
end