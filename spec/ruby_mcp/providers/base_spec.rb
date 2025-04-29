# frozen_string_literal: true

RSpec.describe RubyMCP::Providers::Base do
  let(:config) { { api_key: 'test_key' } }
  let(:provider) { described_class.new(config) }
  
  describe '#initialize' do
    it 'stores the provided configuration' do
      expect(provider.config).to eq(config)
    end
  end
  
  describe '#list_engines' do
    it 'raises NotImplementedError' do
      expect { provider.list_engines }.to raise_error(NotImplementedError)
    end
  end
  
  describe '#generate' do
    it 'raises NotImplementedError' do
      context = instance_double(RubyMCP::Models::Context)
      options = {}
      
      expect { provider.generate(context, options) }.to raise_error(NotImplementedError)
    end
  end
  
  describe '#generate_stream' do
    it 'raises NotImplementedError' do
      context = instance_double(RubyMCP::Models::Context)
      options = {}
      
      expect { provider.generate_stream(context, options) }.to raise_error(NotImplementedError)
    end
  end
  
  describe '#abort_generation' do
    it 'raises NotImplementedError' do
      expect { provider.abort_generation('gen_123') }.to raise_error(NotImplementedError)
    end
  end
  
  # Test protected methods indirectly through public methods
  describe 'api_base (indirectly)' do
    it 'uses the configured api_base if provided' do
      # Create a test subclass that exposes the protected method
      test_provider_class = Class.new(described_class) do
        def get_api_base
          api_base
        end
        
        def default_api_base
          'https://default-api.example.com'
        end
      end
      
      provider = test_provider_class.new(api_base: 'https://custom-api.example.com')
      expect(provider.get_api_base).to eq('https://custom-api.example.com')
    end
    
    it 'uses the default api_base if not configured' do
      # Create a test subclass that exposes the protected method
      test_provider_class = Class.new(described_class) do
        def get_api_base
          api_base
        end
        
        def default_api_base
          'https://default-api.example.com'
        end
      end
      
      provider = test_provider_class.new
      expect(provider.get_api_base).to eq('https://default-api.example.com')
    end
  end
  
  describe 'provider_name (indirectly)' do
    it 'returns the lowercase class name without namespace' do
      # Create a test subclass that exposes the protected method
      test_provider_class = Class.new(described_class) do
        def get_provider_name
          provider_name
        end
      end
      
      # Set the class name
      stub_const('RubyMCP::Providers::TestProvider', test_provider_class)
      
      provider = RubyMCP::Providers::TestProvider.new
      expect(provider.get_provider_name).to eq('testprovider')
    end
  end
end
