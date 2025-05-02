# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyMCP::StorageFactory do
  let(:memory_config) { double('config', storage_config: { type: :memory }) }
  let(:legacy_memory_config) { double('config', storage: { type: :memory }) }
  let(:unknown_config) { double('config', storage_config: { type: :unknown }) }

  describe '.create' do
    context 'when using new configuration interface (storage_config)' do
      it 'creates a Memory storage when type is :memory' do
        expect(RubyMCP::Storage::Memory).to receive(:new).with({ type: :memory })
        described_class.create(memory_config)
      end

      it 'creates a Memory storage when type is nil' do
        nil_config = double('config', storage_config: { type: nil })
        expect(RubyMCP::Storage::Memory).to receive(:new).with({ type: nil })
        described_class.create(nil_config)
      end

      it 'raises ArgumentError for unknown storage type' do
        expect { described_class.create(unknown_config) }.to raise_error(ArgumentError, /Unknown storage type/)
      end
    end

    context 'when using legacy configuration interface (storage)' do
      it 'creates a Memory storage when type is :memory' do
        expect(RubyMCP::Storage::Memory).to receive(:new).with({ type: :memory })
        described_class.create(legacy_memory_config)
      end
    end

    context 'when using Redis storage' do
      let(:redis_config) { double('config', storage_config: { type: :redis }) }

      it 'attempts to require redis gem' do
        # We'll allow the require to happen but raise an error to prevent actual Redis initialization
        expect(described_class).to receive(:require).with('redis').and_raise(LoadError)

        expect { described_class.create(redis_config) }.to raise_error(LoadError, /requires the redis gem/)
      end
    end

    context 'when using ActiveRecord storage' do
      let(:active_record_config) { double('config', storage_config: { type: :active_record }) }

      it 'attempts to require activerecord gem' do
        # We'll allow the require to happen but raise an error to prevent actual ActiveRecord initialization
        expect(described_class).to receive(:require).with('active_record').and_raise(LoadError)

        expect do
          described_class.create(active_record_config)
        end.to raise_error(LoadError, /requires the activerecord gem/)
      end
    end
  end
end
