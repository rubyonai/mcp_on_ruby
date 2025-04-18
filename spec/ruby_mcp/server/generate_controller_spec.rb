# frozen_string_literal: true

# spec/ruby_mcp/server/generate_controller_spec.rb
require 'spec_helper'

RSpec.describe RubyMCP::Server::GenerateController do
  let(:request) { Rack::Request.new({}) }
  let(:controller) { described_class.new(request) }
  let(:storage) { RubyMCP::Storage::Memory.new }

  before do
    allow(controller).to receive(:storage).and_return(storage)

    # Create a test context with a message
    @context = RubyMCP::Models::Context.new(id: 'ctx_test')
    @context.add_message(RubyMCP::Models::Message.new(
                           role: 'user',
                           content: 'Hello, world!'
                         ))
    storage.create_context(@context)

    # Mock a provider
    @provider = double('Provider')
    allow(@provider).to receive(:generate).and_return({
                                                        content: 'Hello there!',
                                                        provider: 'test',
                                                        model: 'test-model',
                                                        created_at: Time.now.utc.iso8601
                                                      })
    allow(controller).to receive(:get_provider).and_return(@provider)
  end

  describe '#create' do
    it 'generates a response using the specified engine' do
      allow(controller).to receive(:params).and_return({
                                                         context_id: 'ctx_test',
                                                         engine_id: 'test/model'
                                                       })

      status, _, body = controller.create

      expect(status).to eq(200)
      response = JSON.parse(body[0])
      expect(response['content']).to eq('Hello there!')
    end

    it 'updates the context with the assistant message' do
      allow(controller).to receive(:params).and_return({
                                                         context_id: 'ctx_test',
                                                         engine_id: 'test/model'
                                                       })

      controller.create

      context = storage.get_context('ctx_test')
      expect(context.messages.size).to eq(2)
      expect(context.messages.last.role).to eq('assistant')
      expect(context.messages.last.content).to eq('Hello there!')
    end

    it "doesn't update the context when update_context is false" do
      allow(controller).to receive(:params).and_return({
                                                         context_id: 'ctx_test',
                                                         engine_id: 'test/model',
                                                         update_context: false
                                                       })

      controller.create

      context = storage.get_context('ctx_test')
      expect(context.messages.size).to eq(1) # Still just the original message
    end

    it 'returns 404 for non-existent context' do
      allow(controller).to receive(:params).and_return({
                                                         context_id: 'nonexistent',
                                                         engine_id: 'test/model'
                                                       })

      status, = controller.create

      expect(status).to eq(404)
    end
  end

  describe '#stream' do
    it 'sets up streaming response headers' do
      # Set HTTP_VERSION to ensure the request is compatible with streaming
      request = Rack::Request.new({ 'HTTP_VERSION' => 'HTTP/1.1' })
      controller = described_class.new(request)
      allow(controller).to receive(:storage).and_return(storage)
      allow(controller).to receive(:get_provider).and_return(@provider)

      allow(controller).to receive(:params).and_return({
                                                         context_id: 'ctx_test',
                                                         engine_id: 'test/model'
                                                       })

      # This test is trickier because streaming depends on environment
      # For now, just check that it attempts to set up a streaming response
      allow(@provider).to receive(:generate_stream)

      status, headers, = controller.stream

      expect(status).to eq(200)
      expect(headers['Content-Type']).to eq('text/event-stream')
      expect(headers['Cache-Control']).to eq('no-cache')
    end
  end
end
