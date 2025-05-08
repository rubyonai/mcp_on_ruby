# frozen_string_literal: true

module RubyMCP
  class Configuration
    attr_accessor :log_level, :transport, :port, :host
    attr_accessor :auth_enabled, :auth_method, :oauth_config
    attr_accessor :default_timeout

    def initialize
      @log_level = Logger::INFO
      @transport = :http
      @port = 3000
      @host = '0.0.0.0'
      @auth_enabled = false
      @auth_method = :none
      @default_timeout = 30 # seconds
    end
  end
end