# lib/ruby_mcp/storage_factory.rb
# frozen_string_literal: true

module RubyMCP
  class StorageFactory
    def self.create(config)
      # Get the storage configuration directly from config.storage
      storage_config = config.storage

      case storage_config[:type]
      when :memory, nil
        Storage::Memory.new(storage_config)
      when :redis
        # Load Redis dependencies
        begin
          require 'redis'
          require_relative 'storage/redis'
        rescue LoadError => e
          raise LoadError, "Redis storage requires the redis gem. Add it to your Gemfile: #{e.message}"
        end

        Storage::Redis.new(storage_config)
      else
        raise ArgumentError, "Unknown storage type: #{storage_config[:type]}"
      end
    end
  end
end
