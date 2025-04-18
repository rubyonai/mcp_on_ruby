# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'

# Define test provider outside of the spec block to avoid constant-in-block warnings
module RubyMCP
  module Providers
    class Test < Base
      def list_engines
        [
          RubyMCP::Models::Engine.new(
            id: 'test/model-1',
            provider: 'test',
            model: 'model-1',
            capabilities: ['text-generation']
          )
        ]
      end

      def generate(context, options = {})
        last_message = context.messages.last
        {
          content: "You said: #{last_message.content}",
          provider: 'test',
          model: options[:model] || 'model-1',
          created_at: Time.now.utc.iso8601
        }
      end

      protected

      def default_api_base
        'https://api.test.com'
      end
    end
  end
end

RSpec.describe 'Conversation flow' do
  include Rack::Test::Methods

  let(:app) { RubyMCP::Server::App.new.rack_app }

  before do
    # Configure with the test provider and in-memory storage
    RubyMCP.configure do |config|
      config.providers = {
        test: { api_key: 'test_key' }
      }
      config.storage = :memory
    end
  end

  it 'supports a multi-turn conversation' do
    # Step 1: Create a context
    post '/contexts', { messages: [{ role: 'system', content: 'You are a test assistant.' }] }.to_json,
         { 'CONTENT_TYPE' => 'application/json' }
    expect(last_response.status).to eq(201)

    context = JSON.parse(last_response.body)
    context_id = context['id']

    # Step 2: First user message
    post '/messages', { context_id: context_id, role: 'user', content: 'Hello there' }.to_json,
         { 'CONTENT_TYPE' => 'application/json' }
    expect(last_response.status).to eq(201)

    # Step 3: First assistant response
    post '/generate', { context_id: context_id, engine_id: 'test/model-1' }.to_json,
         { 'CONTENT_TYPE' => 'application/json' }
    expect(last_response.status).to eq(200)

    response1 = JSON.parse(last_response.body)
    expect(response1['content']).to eq('You said: Hello there')

    # Step 4: Second user message
    post '/messages', { context_id: context_id, role: 'user', content: 'How are you?' }.to_json,
         { 'CONTENT_TYPE' => 'application/json' }
    expect(last_response.status).to eq(201)

    # Step 5: Second assistant response
    post '/generate', { context_id: context_id, engine_id: 'test/model-1' }.to_json,
         { 'CONTENT_TYPE' => 'application/json' }
    expect(last_response.status).to eq(200)

    response2 = JSON.parse(last_response.body)
    expect(response2['content']).to eq('You said: How are you?')

    # Step 6: Verify the full conversation context
    get "/contexts/#{context_id}"
    expect(last_response.status).to eq(200)

    full_context = JSON.parse(last_response.body)
    expect(full_context['messages'].size).to eq(5) # system + 2 user + 2 assistant
    expect(full_context['messages'][0]['role']).to eq('system')
    expect(full_context['messages'][1]['role']).to eq('user')
    expect(full_context['messages'][2]['role']).to eq('assistant')
    expect(full_context['messages'][3]['role']).to eq('user')
    expect(full_context['messages'][4]['role']).to eq('assistant')
  end
end
