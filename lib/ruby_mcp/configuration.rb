# frozen_string_literal: true

module RubyMCP
  class Configuration
    attr_accessor :providers, :storage, :server_port, :server_host,
                  :auth_required, :jwt_secret, :token_expiry, :max_contexts, 
                  :redis, :active_record

    def initialize
      @providers = {}
      @storage = :memory
      @server_port = 3000
      @server_host = '0.0.0.0'
      @auth_required = false
      @jwt_secret = nil
      @token_expiry = 3600 # 1 hour
      @max_contexts = 1000
      @redis = {}         # Default empty Redis config
      @active_record = {} # Default empty ActiveRecord config
    end

    def storage_config
      case @storage
      when :redis
        {
          type: :redis,
          connection: redis_connection_config,
          namespace: @redis[:namespace] || 'ruby_mcp',
          ttl: @redis[:ttl] || 86_400
        }
      when :active_record
        {
          type: :active_record,
          connection: @active_record[:connection],
          table_prefix: @active_record[:table_prefix] || 'mcp_'
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
                              begin
                                require 'redis'
                                require_relative 'storage/redis'
                                RubyMCP::Storage::Redis.new(storage_config)
                              rescue LoadError => e
                                raise RubyMCP::Errors::ConfigurationError, 
                                      "Redis storage requires the redis gem. Add it to your Gemfile with: gem 'redis', '~> 5.0'"
                              end
                            when :active_record
                              begin
                                require 'active_record'
                                require_relative 'storage/active_record'
                                RubyMCP::Storage::ActiveRecord.new(storage_config)
                              rescue LoadError => e
                                raise RubyMCP::Errors::ConfigurationError, 
                                      "ActiveRecord storage requires the activerecord gem. Add it to your Gemfile with: gem 'activerecord', '~> 6.0'"
                              end
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