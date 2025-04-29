# frozen_string_literal: true

RSpec.describe RubyMCP::Configuration do
  it 'has default values' do
    config = RubyMCP::Configuration.new

    expect(config.providers).to eq({})
    expect(config.storage).to eq(:memory)
    expect(config.server_port).to eq(3000)
    expect(config.server_host).to eq('0.0.0.0')
    expect(config.auth_required).to eq(false)
    expect(config.jwt_secret).to be_nil
    expect(config.token_expiry).to eq(3600)
    expect(config.max_contexts).to eq(1000)
  end

  it 'returns a memory storage instance by default' do
    config = RubyMCP::Configuration.new

    expect(config.storage_instance).to be_a(RubyMCP::Storage::Memory)
  end

  it 'raises an error for unsupported storage types' do
    config = RubyMCP::Configuration.new
    config.storage = :invalid

    expect { config.storage_instance }.to raise_error(RubyMCP::Errors::ConfigurationError)
  end
  
  describe '#storage_config' do
    it 'returns redis configuration when storage is :redis' do
      config = RubyMCP::Configuration.new
      config.storage = :redis
      config.redis = { url: 'redis://localhost:6379/0' }
      
      expect(config.storage_config).to eq({ url: 'redis://localhost:6379/0' })
    end
    
    it 'returns empty hash for memory storage' do
      config = RubyMCP::Configuration.new
      config.storage = :memory
      
      expect(config.storage_config).to eq({})
    end
    
    it 'returns empty hash for custom storage' do
      config = RubyMCP::Configuration.new
      config.storage = double('CustomStorage')
      
      expect(config.storage_config).to eq({})
    end
  end
  
  describe 'validation' do
    it 'validates that jwt_secret is present when auth_required is true' do
      config = RubyMCP::Configuration.new
      config.auth_required = true
      
      expect { config.validate! }.to raise_error(RubyMCP::Errors::ConfigurationError, /JWT secret must be configured/)
      
      config.jwt_secret = 'secret'
      expect { config.validate! }.not_to raise_error
    end
    
    it 'validates that at least one provider is configured' do
      config = RubyMCP::Configuration.new
      
      expect { config.validate! }.to raise_error(RubyMCP::Errors::ConfigurationError, /At least one provider/)
      
      config.providers = { openai: { api_key: 'test' } }
      expect { config.validate! }.not_to raise_error
    end
  end
end
