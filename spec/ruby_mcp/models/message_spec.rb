# frozen_string_literal: true

RSpec.describe RubyMCP::Models::Message do
  describe '#initialize' do
    it 'creates a message with valid role and content' do
      message = described_class.new(role: 'user', content: 'Hello')
      
      expect(message.role).to eq('user')
      expect(message.content).to eq('Hello')
      expect(message.id).to match(/^msg_[a-f0-9]+$/)
      expect(message.metadata).to eq({})
    end
    
    it 'accepts custom ID and metadata' do
      message = described_class.new(
        role: 'assistant',
        content: 'Hello there',
        id: 'msg_custom',
        metadata: { source: 'test' }
      )
      
      expect(message.id).to eq('msg_custom')
      expect(message.metadata).to eq({ source: 'test' })
    end
    
    it 'raises an error for invalid roles' do
      expect {
        described_class.new(role: 'invalid', content: 'Hello')
      }.to raise_error(RubyMCP::Errors::ValidationError)
    end
  end
  
  describe '#to_h' do
    it 'returns a hash representation of the message' do
      message = described_class.new(
        role: 'user',
        content: 'Hello',
        id: 'msg_123',
        metadata: { source: 'test' }
      )
      
      hash = message.to_h
      
      expect(hash[:id]).to eq('msg_123')
      expect(hash[:role]).to eq('user')
      expect(hash[:content]).to eq('Hello')
      expect(hash[:metadata]).to eq({ source: 'test' })
      expect(hash[:created_at]).to be_a(Time)
    end
  end
  
  describe '#content_type' do
    it 'returns :text for string content' do
      message = described_class.new(role: 'user', content: 'Hello')
      expect(message.content_type).to eq(:text)
    end
    
    it 'returns :array for array content' do
      message = described_class.new(role: 'user', content: [{ type: 'text', text: 'Hello' }])
      expect(message.content_type).to eq(:array)
    end
  end
  
  describe '#estimated_token_count' do
    it 'estimates tokens for text content' do
      message = described_class.new(role: 'user', content: 'Hello world')
      expect(message.estimated_token_count).to be > 0
    end
    
    it 'estimates tokens for array content' do
      message = described_class.new(
        role: 'user',
        content: [{ type: 'text', text: 'Hello world' }]
      )
      expect(message.estimated_token_count).to be > 0
    end
  end
end
