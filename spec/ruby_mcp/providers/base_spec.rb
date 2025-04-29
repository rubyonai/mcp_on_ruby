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
  
  describe '#api_base' do
    it 'returns the configured api_base if provided' do
      provider = described_class.new(api_base: 'https://custom-api.example.com')
      expect(provider.api_base).to eq('https://custom-api.example.com')
    end
    
    it 'returns the default api_base if not configured' do
      expect(provider).to receive(:default_api_base).and_return('https://default-api.example.com')
      expect(provider.api_base).to eq('https://default-api.example.com')
    end
  end
  
  describe '#provider_name' do
    it 'returns the lowercase class name without namespace' do
      expect(provider.provider_name).to eq('base')
    end
  end
end
