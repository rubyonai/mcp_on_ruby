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

      def storage_instance
        @storage_instance ||= begin
          case @storage
          when :memory
            RubyMCP::Storage::Memory.new
          when :redis
            # Future implementation
            raise RubyMCP::Errors::ConfigurationError, "Redis storage not yet implemented"
          when :active_record
            # Future implementation
            raise RubyMCP::Errors::ConfigurationError, "ActiveRecord storage not yet implemented"
          else
            if @storage.is_a?(RubyMCP::Storage::Base)
              @storage  # Allow custom storage instance
            else
              raise RubyMCP::Errors::ConfigurationError, "Unknown storage type: #{@storage}"
            end
          end
        end
      end
    end
  end