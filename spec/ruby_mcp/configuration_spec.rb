# frozen_string_literal: true

RSpec.describe RubyMCP::Configuration do
    it "has default values" do
      config = RubyMCP::Configuration.new
      
      expect(config.providers).to eq({})
      expect(config.storage).to eq(:memory)
      expect(config.server_port).to eq(3000)
      expect(config.server_host).to eq("0.0.0.0")
      expect(config.auth_required).to eq(false)
      expect(config.jwt_secret).to be_nil
      expect(config.token_expiry).to eq(3600)
      expect(config.max_contexts).to eq(1000)
    end
    
    it "returns a memory storage instance by default" do
      config = RubyMCP::Configuration.new
      
      expect(config.storage_instance).to be_a(RubyMCP::Storage::Memory)
    end
    
    it "raises an error for unsupported storage types" do
      config = RubyMCP::Configuration.new
      config.storage = :invalid
      
      expect { config.storage_instance }.to raise_error(RubyMCP::Errors::ConfigurationError)
    end
  end