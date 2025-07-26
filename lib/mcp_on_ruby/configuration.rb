# frozen_string_literal: true

require 'logger'

module McpOnRuby
  # Configuration class for MCP server
  class Configuration
    attr_accessor :log_level,
                  :path,
                  :authentication_required,
                  :authentication_token,
                  :allowed_origins,
                  :localhost_only,
                  :rate_limit_per_minute,
                  :enable_sse,
                  :request_timeout,
                  :cors_enabled,
                  :dns_rebinding_protection

    def initialize
      @log_level = Logger::INFO
      @path = '/mcp'
      @authentication_required = false
      @authentication_token = nil
      @allowed_origins = []
      @localhost_only = false
      @rate_limit_per_minute = 60
      @enable_sse = true
      @request_timeout = 30
      @cors_enabled = true
      @dns_rebinding_protection = true
    end

    # Check if authentication is configured
    # @return [Boolean] True if authentication is properly configured
    def authentication_configured?
      authentication_required && !authentication_token.nil?
    end

    # Check if origin is allowed
    # @param origin [String] The origin to check
    # @return [Boolean] True if origin is allowed
    def origin_allowed?(origin)
      return true if allowed_origins.empty?
      
      allowed_origins.any? do |allowed|
        case allowed
        when String
          origin == allowed
        when Regexp
          origin =~ allowed
        else
          false
        end
      end
    end

    # Check if localhost only mode and origin is localhost
    # @param origin [String] The origin to check
    # @return [Boolean] True if localhost only and origin is localhost
    def localhost_allowed?(origin)
      return true unless localhost_only
      
      localhost_patterns = [
        'http://localhost',
        'https://localhost',
        'http://127.0.0.1',
        'https://127.0.0.1'
      ]
      
      localhost_patterns.any? { |pattern| origin&.start_with?(pattern) }
    end
  end
end