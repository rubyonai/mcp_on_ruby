# frozen_string_literal: true

module RubyMCP
  class StorageFactory
    def self.create(config)
      # Support both old and new configuration interfaces
      storage_config = if config.respond_to?(:storage_config)
                         config.storage_config
                       else
                         config.storage
                       end

      case storage_config[:type]
      when :memory, nil
        Storage::Memory.new(storage_config)
      when :redis
        # Load Redis dependencies
        begin
          require 'redis'
          require_relative 'storage/redis'
        rescue LoadError => e
          raise LoadError, "Redis storage requires the redis gem. Add it to your Gemfile with: gem 'redis', '~> 5.0'"
        end

        Storage::Redis.new(storage_config)
      when :active_record
        # Load ActiveRecord dependencies
        begin
          require 'active_record'
          require_relative 'storage/active_record'
        rescue LoadError => e
          raise LoadError, "ActiveRecord storage requires the activerecord gem. Add it to your Gemfile with: gem 'activerecord', '~> 6.0'"
        end

        Storage::ActiveRecord.new(storage_config)
      else
        raise ArgumentError, "Unknown storage type: #{storage_config[:type]}"
      end
    end
  end
end