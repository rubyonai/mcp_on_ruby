# frozen_string_literal: true

require "spec_helper"
require "ruby_mcp/storage_factory"

RSpec.describe RubyMCP::StorageFactory do
  describe ".create" do
    let(:config) { double("Config") }
    
    it "creates in-memory storage by default" do
      allow(config).to receive(:storage).and_return({ type: :memory })
      
      storage = described_class.create(config)
      
      expect(storage).to be_a(RubyMCP::Storage::Memory)
    end
    
    it "creates Redis storage when configured" do
      redis_config = {
        type: :redis,
        connection: { url: "redis://localhost:6379/1" },
        namespace: "ruby_mcp_test",
        ttl: 3600
      }
      allow(config).to receive(:storage).and_return(redis_config)
      
      storage = described_class.create(config)
      
      expect(storage).to be_a(RubyMCP::Storage::Redis)
      expect(storage.instance_variable_get(:@namespace)).to eq("ruby_mcp_test")
      expect(storage.instance_variable_get(:@ttl)).to eq(3600)
    end
    
    it "raises an error for unknown storage type" do
      allow(config).to receive(:storage).and_return({ type: :unknown })
      
      expect { described_class.create(config) }.to raise_error(ArgumentError)
    end
  end
end