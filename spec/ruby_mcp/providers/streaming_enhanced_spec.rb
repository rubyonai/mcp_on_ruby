# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Enhanced Streaming Tests' do
  let(:api_key) { 'test_api_key' }

  describe 'OpenAI streaming with tool calls' do
    let(:provider) { RubyMCP::Providers::Openai.new(api_key: api_key) }
    let(:context) do
      RubyMCP::Models::Context.new.tap do |ctx|
        ctx.add_message(RubyMCP::Models::Message.new(role: 'user', content: 'What is the weather in San Francisco?'))
      end
    end

    it 'handles tool calls in streaming mode' do
      # Mock a streaming tool call response
      stub_request(:post, 'https://api.openai.com/v1/chat/completions')
        .to_return(
          status: 200,
          headers: { 'Content-Type' => 'text/event-stream' },
          body: [
            "data: #{
              { 'choices' => [{ 'delta' => { 'tool_calls' => [
                { 'index' => 0, 'function' => { 'name' => 'get_' } }
              ] } }] }.to_json
            }\n\n",
            "data: #{
              { 'choices' => [{ 'delta' => { 'tool_calls' => [
                { 'index' => 0, 'function' => { 'name' => 'weather' } }
              ] } }] }.to_json
            }\n\n",
            "data: #{
              { 'choices' => [{ 'delta' => { 'tool_calls' => [
                { 'index' => 0, 'function' => { 'arguments' => '{\"loc' } }
              ] } }] }.to_json
            }\n\n",
            "data: #{
              { 'choices' => [{ 'delta' => { 'tool_calls' => [
                { 'index' => 0, 'function' => { 'arguments' => 'ation\":\"San ' } }
              ] } }] }.to_json
            }\n\n",
            "data: #{
              { 'choices' => [{ 'delta' => { 'tool_calls' => [
                { 'index' => 0, 'function' => { 'arguments' => 'Francisco\"}' } }
              ] } }] }.to_json
            }\n\n",
            "data: [DONE]\n\n"
          ].join
        )

      chunks = []
      provider.generate_stream(context, { model: 'gpt-4', tools: [{ name: 'get_weather' }] }) do |chunk|
        chunks << chunk
      end

      # Verify sequence of events
      expect(chunks.any? { |c| c[:event] == 'generation.start' }).to be true
      expect(chunks.any? { |c| c[:event] == 'generation.tool_call' }).to be true
      expect(chunks.any? { |c| c[:event] == 'generation.complete' }).to be true

      # Check that we have tool_calls in at least one event
      tool_call_events = chunks.select { |c| c[:event] == 'generation.tool_call' }
      expect(tool_call_events).not_to be_empty

      # Assert on the structure of the tool calls rather than using symbol keys
      last_tool_call = tool_call_events.last
      expect(last_tool_call).to have_key(:tool_calls)
      expect(last_tool_call[:tool_calls]).to be_an(Array)
      expect(last_tool_call[:tool_calls].first).to have_key('function')
      expect(last_tool_call[:tool_calls].first['function']).to have_key('name')
      expect(last_tool_call[:tool_calls].first['function']['name']).to eq('get_weather')
      expect(last_tool_call[:tool_calls].first['function']).to have_key('arguments')
    end

    it 'handles streaming errors gracefully' do
      # Mock a streaming error response
      stub_request(:post, 'https://api.openai.com/v1/chat/completions')
        .to_raise(Faraday::TimeoutError.new('Request timed out'))

      expect do
        provider.generate_stream(context, { model: 'gpt-4' }) { |_chunk| }
      end.to raise_error(RubyMCP::Errors::ProviderError, /streaming failed/)
    end
  end

  describe 'Anthropic streaming with tool calls' do
    let(:provider) { RubyMCP::Providers::Anthropic.new(api_key: api_key) }
    let(:context) do
      RubyMCP::Models::Context.new.tap do |ctx|
        ctx.add_message(RubyMCP::Models::Message.new(role: 'user', content: 'What is the weather in San Francisco?'))
      end
    end

    it 'handles tool calls in streaming mode' do
      # Mock a streaming tool call response for Anthropic
      stub_request(:post, 'https://api.anthropic.com/v1/messages')
        .to_return(
          status: 200,
          headers: { 'Content-Type' => 'text/event-stream' },
          body: [
            "data: #{{ 'type' => 'message_start' }.to_json}\n\n",
            "data: #{{ 'type' => 'tool_call', 'id' => 'tc_123', 'name' => 'get_weather',
                       'input' => '{"location":"San Francisco"}' }.to_json}\n\n",
            "data: #{{ 'type' => 'message_stop' }.to_json}\n\n"
          ].join
        )

      chunks = []
      provider.generate_stream(context,
                               { model: 'claude-3-opus-20240229', tools: [{ name: 'get_weather' }] }) do |chunk|
        chunks << chunk
      end

      # Verify sequence of events
      expect(chunks.any? { |c| c[:event] == 'generation.start' }).to be true
      expect(chunks.any? { |c| c[:event] == 'generation.tool_call' }).to be true
      expect(chunks.any? { |c| c[:event] == 'generation.complete' }).to be true

      # Check that we have tool_calls in at least one event
      tool_call_events = chunks.select { |c| c[:event] == 'generation.tool_call' }
      expect(tool_call_events).not_to be_empty

      # Assert on the structure of the tool calls rather than using symbol keys
      last_tool_call = tool_call_events.last
      expect(last_tool_call).to have_key(:tool_calls)
      expect(last_tool_call[:tool_calls]).to be_an(Array)
      expect(last_tool_call[:tool_calls].first).to have_key('function')
      expect(last_tool_call[:tool_calls].first['function']).to have_key('name')
    end

    it 'handles mixed content types, including JSON parsing errors' do
      # Mock a streaming response with various content types including invalid JSON
      stub_request(:post, 'https://api.anthropic.com/v1/messages')
        .to_return(
          status: 200,
          headers: { 'Content-Type' => 'text/event-stream' },
          body: [
            "data: #{{ 'type' => 'message_start' }.to_json}\n\n",
            "data: #{{ 'type' => 'content_block_delta', 'delta' => { 'text' => 'Here is the weather' } }.to_json}\n\n",
            "data: invalid-json-that-should-be-skipped\n\n",
            "data: #{{ 'type' => 'message_stop' }.to_json}\n\n"
          ].join
        )

      chunks = []
      provider.generate_stream(context, { model: 'claude-3-opus-20240229' }) do |chunk|
        chunks << chunk
      end

      # Verify content events were processed correctly
      content_events = chunks.select { |c| c[:event] == 'generation.content' }
      expect(content_events.size).to eq(1)
      expect(content_events.first[:content]).to eq('Here is the weather')

      # Verify the complete event contains the full content
      complete_event = chunks.find { |c| c[:event] == 'generation.complete' }
      expect(complete_event[:content]).to eq('Here is the weather')
    end
  end

  describe 'Structured content handling' do
    let(:provider) { RubyMCP::Providers::Openai.new(api_key: api_key) }

    it 'formats structured content properly for generation' do
      # Create a context with structured content
      context = RubyMCP::Models::Context.new
      structured_message = RubyMCP::Models::Message.new(
        role: 'user',
        content: [
          "Here's an image: ",
          { type: 'content_pointer', content_id: 'img_123' },
          ' What do you see in it?'
        ]
      )
      context.add_message(structured_message)

      # Verify the provider correctly formats the structured content
      stub_request(:post, 'https://api.openai.com/v1/chat/completions')
        .with do |request|
          body = JSON.parse(request.body)
          messages = body['messages']
          # Check that the structured content is correctly converted to OpenAI's format
          content_parts = messages[0]['content']
          content_parts.is_a?(Array) &&
            content_parts.size == 3 &&
            content_parts[0]['type'] == 'text' &&
            content_parts[1]['type'] == 'text' &&
            content_parts[1]['text'].include?('Content reference: img_123')
        end
        .to_return(
          status: 200,
          headers: { 'Content-Type' => 'application/json' },
          body: { 'choices' => [{ 'message' => { 'content' => 'I see an image!' } }] }.to_json
        )

      response = provider.generate(context, { model: 'gpt-4' })
      expect(response[:content]).to eq('I see an image!')
    end
  end
end
