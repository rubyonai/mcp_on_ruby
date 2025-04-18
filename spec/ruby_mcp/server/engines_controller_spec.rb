# frozen_string_literal: true

# spec/ruby_mcp/server/engines_controller_spec.rb
require 'spec_helper'

RSpec.describe RubyMCP::Server::EnginesController do
  let(:request) { Rack::Request.new({}) }
  let(:controller) { described_class.new(request) }

  describe '#index' do
    it 'returns a list of engines from all providers' do
      # Setup mock provider that returns engines
      provider_class = Class.new(RubyMCP::Providers::Base) do
        def list_engines
          [
            RubyMCP::Models::Engine.new(
              id: 'test/engine-1',
              provider: 'test',
              model: 'engine-1',
              capabilities: ['text-generation']
            )
          ]
        end
      end

      # Configure with the mock provider
      RubyMCP.configure do |config|
        config.providers = { test: {} }
      end

      # Stub the provider class lookup
      expect(controller).to receive(:get_provider_class).with(:test).and_return(provider_class)

      # Call the action
      status, _, body = controller.index

      # Verify response
      expect(status).to eq(200)
      expect(JSON.parse(body[0])['engines'].first['id']).to eq('test/engine-1')
    end
  end
end
