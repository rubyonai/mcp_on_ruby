# frozen_string_literal: true

RSpec.describe RubyMCP::Models::Engine do
  describe '#initialize' do
    it 'creates an engine with required attributes' do
      engine = described_class.new(
        id: 'openai/gpt-4',
        provider: 'openai',
        model: 'gpt-4'
      )

      expect(engine.id).to eq('openai/gpt-4')
      expect(engine.provider).to eq('openai')
      expect(engine.model).to eq('gpt-4')
      expect(engine.capabilities).to eq([])
      expect(engine.config).to eq({})
    end

    it 'accepts optional capabilities and config' do
      engine = described_class.new(
        id: 'openai/gpt-4',
        provider: 'openai',
        model: 'gpt-4',
        capabilities: %w[text-generation streaming],
        config: { max_tokens: 4096 }
      )

      expect(engine.capabilities).to eq(%w[text-generation streaming])
      expect(engine.config).to eq({ max_tokens: 4096 })
    end
  end

  describe '#to_h' do
    it 'returns a hash representation of the engine' do
      engine = described_class.new(
        id: 'openai/gpt-4',
        provider: 'openai',
        model: 'gpt-4',
        capabilities: ['text-generation'],
        config: { max_tokens: 4096 }
      )

      hash = engine.to_h

      expect(hash[:id]).to eq('openai/gpt-4')
      expect(hash[:provider]).to eq('openai')
      expect(hash[:model]).to eq('gpt-4')
      expect(hash[:capabilities]).to eq(['text-generation'])
      expect(hash[:config]).to eq({ max_tokens: 4096 })
    end
  end
end
