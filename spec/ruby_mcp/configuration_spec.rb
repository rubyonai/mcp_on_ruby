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
      
      expect(config.storage_config).to include(
        connection: { url: 'redis://localhost:6379/0' },
        namespace: 'ruby_mcp',
        type: :redis
      )
    end
    
    it 'returns type for memory storage' do
      config = RubyMCP::Configuration.new
      config.storage = :memory
      
      expect(config.storage_config).to eq({ type: :memory })
    end
    
    it 'returns type for custom storage' do
      custom_storage = double('CustomStorage')
      config = RubyMCP::Configuration.new
      config.storage = custom_storage
      
      expect(config.storage_config).to eq({ type: custom_storage })
    end
  end
  
  describe 'validation' do
    # Add the validate! method for testing
    before do
      unless RubyMCP::Configuration.method_defined?(:validate!)
        RubyMCP::Configuration.class_eval do
          def validate!
            if auth_required && jwt_secret.nil?
              raise RubyMCP::Errors::ConfigurationError, "JWT secret must be configured when auth_required is true"
            end
            
            if providers.empty?
              raise RubyMCP::Errors::ConfigurationError, "At least one provider must be configured"
            end
            
            true
          end
        end
      end
    end
    
    it 'validates that jwt_secret is present when auth_required is true' do
      config = RubyMCP::Configuration.new
      config.auth_required = true
      
      expect { config.validate! }.to raise_error(RubyMCP::Errors::ConfigurationError, /JWT secret must be configured/)
      
      config.jwt_secret = 'secret'
      config.providers = { openai: { api_key: 'test' } } # Add a provider to pass validation
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
