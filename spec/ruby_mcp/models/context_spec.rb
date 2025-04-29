# frozen_string_literal: true

RSpec.describe RubyMCP::Models::Context do
  describe '#initialize' do
    it 'creates a context with default values' do
      context = described_class.new

      expect(context.id).to match(/^ctx_[a-f0-9]+$/)
      expect(context.messages).to eq([])
      expect(context.content_map).to eq({})
      expect(context.metadata).to eq({})
      expect(context.created_at).to be_a(Time)
      expect(context.updated_at).to be_a(Time)
    end

    it 'accepts custom ID, messages, and metadata' do
      messages = [RubyMCP::Models::Message.new(role: 'user', content: 'Hello')]
      context = described_class.new(
        id: 'ctx_custom',
        messages: messages,
        metadata: { source: 'test' }
      )

      expect(context.id).to eq('ctx_custom')
      expect(context.messages).to eq(messages)
      expect(context.metadata).to eq({ source: 'test' })
    end
  end

  describe '#add_message' do
    let(:context) { described_class.new }
    let(:message) { RubyMCP::Models::Message.new(role: 'user', content: 'Hello') }

    it 'adds a message to the context' do
      context.add_message(message)
      expect(context.messages).to include(message)
    end

    it 'updates the updated_at timestamp' do
      original_time = context.updated_at
      sleep(0.001) # Ensure time difference
      context.add_message(message)
      expect(context.updated_at).to be > original_time
    end
  end

  describe '#add_content' do
    let(:context) { described_class.new }

    it 'adds content to the content map' do
      context.add_content('cnt_123', { type: 'file', data: 'test' })
      expect(context.content_map['cnt_123']).to eq({ type: 'file', data: 'test' })
    end

    it 'returns the content_id' do
      result = context.add_content('cnt_456', { type: 'image', data: 'image_data' })
      expect(result).to eq('cnt_456')
    end

    it 'updates the updated_at timestamp' do
      original_time = context.updated_at
      sleep(0.001) # Ensure time difference
      context.add_content('cnt_789', { type: 'file', data: 'test' })
      expect(context.updated_at).to be > original_time
    end
  end

  describe '#get_content' do
    let(:context) { described_class.new }

    it 'retrieves content by id' do
      content_data = { type: 'file', data: 'test_content' }
      context.add_content('cnt_123', content_data)

      result = context.get_content('cnt_123')
      expect(result).to eq(content_data)
    end

    it 'returns nil for non-existent content' do
      result = context.get_content('nonexistent')
      expect(result).to be_nil
    end
  end

  describe '#to_h' do
    it 'returns a hash representation of the context' do
      message = RubyMCP::Models::Message.new(role: 'user', content: 'Hello')
      context = described_class.new(
        id: 'ctx_123',
        messages: [message],
        metadata: { source: 'test' }
      )
      context.add_content('cnt_123', { type: 'file', data: 'test' })

      hash = context.to_h

      expect(hash[:id]).to eq('ctx_123')
      expect(hash[:messages]).to be_an(Array)
      expect(hash[:messages].first).to be_a(Hash)
      expect(hash).to have_key(:content_map)
      expect(hash[:metadata]).to eq({ source: 'test' })
      expect(hash[:created_at]).to be_a(String)
      expect(hash[:updated_at]).to be_a(String)
    end
  end

  describe '#estimated_token_count' do
    it 'estimates tokens based on messages' do
      context = described_class.new
      context.add_message(RubyMCP::Models::Message.new(role: 'user', content: 'Hello world'))
      context.add_message(RubyMCP::Models::Message.new(role: 'assistant', content: 'Hi there'))

      expect(context.estimated_token_count).to be > 0
    end
  end
end
