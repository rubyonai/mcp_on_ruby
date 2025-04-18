# frozen_string_literal: true

module RubyMCP
  module Errors
    class Error < StandardError; end

    class ConfigurationError < Error; end
    class AuthenticationError < Error; end
    class ValidationError < Error; end
    class ProviderError < Error; end
    class ContextError < Error; end
    class EngineError < Error; end
    class MessageError < Error; end
    class ContentError < Error; end
    class ServerError < Error; end
  end
end
