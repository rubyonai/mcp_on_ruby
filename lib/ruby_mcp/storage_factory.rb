# frozen_string_literal: true

module RubyMCP
    # Factory class for creating storage instances based on configuration
    class StorageFactory
      def self.create(config)
        storage_config = config.storage
        
        case storage_config[:type]
        when :memory, nil
          Storage::Memory.new(storage_config)
        when :redis
          # Ensure redis gem is available
          begin
            require "redis"
          rescue LoadError
            raise LoadError, "Redis gem is required for Redis storage. Add `gem 'redis'` to your Gemfile."
          end
          
          # Load Redis storage implementation
          begin
            require "ruby_mcp/storage/redis"
          rescue LoadError
            raise LoadError, "Redis storage implementation not found. Ensure redis.rb is present in lib/ruby_mcp/storage/."
          end
          
          Storage::Redis.new(storage_config)
        else
          raise ArgumentError, "Unknown storage type: #{storage_config[:type]}"
        end
      end
    end
  end