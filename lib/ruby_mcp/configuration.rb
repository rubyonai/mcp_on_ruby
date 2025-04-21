# frozen_string_literal: true

module RubyMCP
  class Configuration
    attr_accessor :providers, :storage, :server_port, :server_host,
                  :auth_required, :jwt_secret, :token_expiry, :max_contexts, :redis

    def initialize
      @providers = {}
      @storage = :memory
      @server_port = 3000
      @server_host = '0.0.0.0'
      @auth_required = false
      @jwt_secret = nil
      @token_expiry = 3600 # 1 hour
      @max_contexts = 1000
      @storage = :memory  # Default to memory storage
      @redis = {}         # Default empty Redis config
    end

    def storage_config
      if @storage == :redis
        {
          type: :redis,
          connection: redis_connection_config,
          namespace: @redis[:namespace] || 'ruby_mcp',
          ttl: @redis[:ttl] || 86_400
        }
      else
        { type: @storage }
      end
    end

    def storage_instance
      @storage_instance ||= case @storage
                            when :memory
                              RubyMCP::Storage::Memory.new
                            when :redis
                              # Future implementation
                              raise RubyMCP::Errors::ConfigurationError, 'Redis storage not yet implemented'
                            when :active_record
                              # Future implementation
                              raise RubyMCP::Errors::ConfigurationError, 'ActiveRecord storage not yet implemented'
                            else
                              unless @storage.is_a?(RubyMCP::Storage::Base)
                                raise RubyMCP::Errors::ConfigurationError, "Unknown storage type: #{@storage}"
                              end

                              @storage # Allow custom storage instance

                            end
    end

    private

    def redis_connection_config
      if @redis[:url]
        { url: @redis[:url] }
      else
        {
          host: @redis[:host] || 'localhost',
          port: @redis[:port] || 6379,
          db: @redis[:db] || 0,
          password: @redis[:password]
        }.compact
      end
    end
  end
end
