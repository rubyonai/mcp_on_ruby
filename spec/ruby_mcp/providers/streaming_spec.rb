# frozen_string_literal: true

# spec/ruby_mcp/providers/streaming_spec.rb
require 'spec_helper'

RSpec.describe 'Streaming functionality' do
  let(:api_key) { 'test_api_key' }

  describe 'OpenAI streaming' do
    let(:provider) { RubyMCP::Providers::Openai.new(api_key: api_key) }
    let(:context) do
      RubyMCP::Models::Context.new.tap do |ctx|
        ctx.add_message(RubyMCP::Models::Message.new(role: 'user', content: 'Hello'))
      end
    end

    it 'processes streamed chunks' do
      # Setup a mock response that returns multiple chunks
      stub_request(:post, 'https://api.openai.com/v1/chat/completions')
        .to_return(
          status: 200,
          headers: { 'Content-Type' => 'text/event-stream' },
          body: [
            "data: #{{ 'choices' => [{ 'delta' => { 'content' => 'Hello' } }] }.to_json}\n\n",
            "data: #{{ 'choices' => [{ 'delta' => { 'content' => ' world' } }] }.to_json}\n\n",
            "data: #{{ 'choices' => [{ 'delta' => { 'content' => '!' } }] }.to_json}\n\n",
            "data: [DONE]\n\n"
          ].join
        )

      chunks = []
      provider.generate_stream(context, { model: 'gpt-4' }) do |chunk|
        chunks << chunk
      end

      # Instead of checking exact count, check for specific events
      expect(chunks.any? { |c| c[:event] == 'generation.start' }).to be true
      expect(chunks.any? { |c| c[:content] == 'Hello' }).to be true
      expect(chunks.any? { |c| c[:content] == ' world' }).to be true
      expect(chunks.any? { |c| c[:content] == '!' }).to be true
      expect(chunks.any? { |c| c[:event] == 'generation.complete' }).to be true

      # Verify the complete content is provided in the final event
      complete_event = chunks.find { |c| c[:event] == 'generation.complete' }
      expect(complete_event[:content]).to eq('Hello world!')
    end
  end
end
