# frozen_string_literal: true

module RubyMCP
    class Configuration
      attr_accessor :providers, :storage, :server_port, :server_host, 
                    :auth_required, :jwt_secret, :token_expiry, :max_contexts
  
      def initialize
        @providers = {}
        @storage = :memory
        @server_port = 3000
        @server_host = "0.0.0.0"
        @auth_required = false
        @jwt_secret = nil
        @token_expiry = 3600 # 1 hour
        @max_contexts = 1000
      end
    end
  end