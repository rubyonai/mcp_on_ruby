# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyMCP::Configuration do
  describe '#storage_config' do
    context 'with redis storage' do
      let(:config) do
        config = described_class.new
        config.storage = :redis
        config
      end

      it 'returns default redis configuration when no specifics are provided' do
        expect(config.storage_config).to eq({
                                              type: :redis,
                                              connection: {
                                                host: 'localhost',
                                                port: 6379,
                                                db: 0
                                              },
                                              namespace: 'ruby_mcp',
                                              ttl: 86_400
                                            })
      end

      it 'uses custom redis URL when provided' do
        config.redis = { url: 'redis://custom-host:1234/5' }

        expect(config.storage_config).to eq({
                                              type: :redis,
                                              connection: { url: 'redis://custom-host:1234/5' },
                                              namespace: 'ruby_mcp',
                                              ttl: 86_400
                                            })
      end

      it 'uses custom redis connection parameters when provided' do
        config.redis = {
          host: 'custom-host',
          port: 1234,
          db: 5,
          password: 'secret'
        }

        expect(config.storage_config).to eq({
                                              type: :redis,
                                              connection: {
                                                host: 'custom-host',
                                                port: 1234,
                                                db: 5,
                                                password: 'secret'
                                              },
                                              namespace: 'ruby_mcp',
                                              ttl: 86_400
                                            })
      end

      it 'uses custom namespace and ttl when provided' do
        config.redis = {
          namespace: 'custom-namespace',
          ttl: 3600
        }

        expect(config.storage_config).to eq({
                                              type: :redis,
                                              connection: {
                                                host: 'localhost',
                                                port: 6379,
                                                db: 0
                                              },
                                              namespace: 'custom-namespace',
                                              ttl: 3600
                                            })
      end
    end

    context 'with active_record storage' do
      let(:config) do
        config = described_class.new
        config.storage = :active_record
        config
      end

      it 'returns default active_record configuration when minimal details provided' do
        config.active_record = {
          connection: { adapter: 'sqlite3', database: ':memory:' }
        }

        expect(config.storage_config).to eq({
                                              type: :active_record,
                                              connection: { adapter: 'sqlite3', database: ':memory:' },
                                              table_prefix: 'mcp_'
                                            })
      end

      it 'uses custom table prefix when provided' do
        config.active_record = {
          connection: { adapter: 'sqlite3', database: ':memory:' },
          table_prefix: 'custom_prefix_'
        }

        expect(config.storage_config).to eq({
                                              type: :active_record,
                                              connection: { adapter: 'sqlite3', database: ':memory:' },
                                              table_prefix: 'custom_prefix_'
                                            })
      end
    end
  end

  describe '#storage_instance' do
    let(:config) { described_class.new }

    # Define module for tests
    before(:all) do
      unless defined?(RubyMCP::Storage::Redis)
        module RubyMCP
          module Storage
            class Redis < Base
            end
          end
        end
      end

      unless defined?(RubyMCP::Storage::ActiveRecord)
        module RubyMCP
          module Storage
            class ActiveRecord < Base
            end
          end
        end
      end
    end

    context 'when using redis storage' do
      before do
        config.storage = :redis
        # Mock the require methods to avoid actual dependency loading
        allow(config).to receive(:require).with('redis').and_return(true)
        allow(config).to receive(:require_relative).with('storage/redis').and_return(true)
        # Stub the Redis class creation to avoid actual Redis connections
        allow(RubyMCP::Storage::Redis).to receive(:new).and_return(double('redis_storage'))
      end

      it 'creates a Redis storage instance' do
        expect(config.storage_instance).to be_truthy
        expect(RubyMCP::Storage::Redis).to have_received(:new)
      end

      it 'raises an error when redis gem is not available' do
        allow(config).to receive(:require).with('redis').and_raise(LoadError)

        expect { config.storage_instance }.to raise_error(
          RubyMCP::Errors::ConfigurationError,
          /Redis storage requires the redis gem/
        )
      end
    end

    context 'when using active_record storage' do
      before do
        config.storage = :active_record
        # Mock the require methods to avoid actual dependency loading
        allow(config).to receive(:require).with('active_record').and_return(true)
        allow(config).to receive(:require_relative).with('storage/active_record').and_return(true)
        # Stub the ActiveRecord class creation
        allow(RubyMCP::Storage::ActiveRecord).to receive(:new).and_return(double('ar_storage'))
      end

      it 'creates an ActiveRecord storage instance' do
        expect(config.storage_instance).to be_truthy
        expect(RubyMCP::Storage::ActiveRecord).to have_received(:new)
      end

      it 'raises an error when activerecord gem is not available' do
        allow(config).to receive(:require).with('active_record').and_raise(LoadError)

        expect { config.storage_instance }.to raise_error(
          RubyMCP::Errors::ConfigurationError,
          /ActiveRecord storage requires the activerecord gem/
        )
      end
    end

    context 'when providing a custom storage instance' do
      it 'accepts a custom storage instance that inherits from Base' do
        custom_storage = instance_double('RubyMCP::Storage::Base')
        allow(custom_storage).to receive(:is_a?).with(RubyMCP::Storage::Base).and_return(true)

        config.storage = custom_storage
        expect(config.storage_instance).to eq(custom_storage)
      end

      it 'raises an error for unknown storage types' do
        config.storage = :unknown

        expect { config.storage_instance }.to raise_error(
          RubyMCP::Errors::ConfigurationError,
          /Unknown storage type/
        )
      end

      it 'raises an error for invalid storage instance' do
        invalid_storage = double('NotAStorageClass')
        allow(invalid_storage).to receive(:is_a?).with(RubyMCP::Storage::Base).and_return(false)

        config.storage = invalid_storage
        expect { config.storage_instance }.to raise_error(
          RubyMCP::Errors::ConfigurationError,
          /Unknown storage type/
        )
      end
    end
  end
end
