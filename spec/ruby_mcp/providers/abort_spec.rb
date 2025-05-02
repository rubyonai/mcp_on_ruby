# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Generation Abortion' do
  let(:api_key) { 'test_api_key' }

  describe 'OpenAI abort_generation' do
    let(:provider) { RubyMCP::Providers::Openai.new(api_key: api_key) }
    let(:generation_id) { 'gen_123' }

    it 'raises a provider error since OpenAI does not support abortion' do
      expect { provider.abort_generation(generation_id) }.to raise_error(
        RubyMCP::Errors::ProviderError,
        /OpenAI doesn't support aborting generations/
      )
    end
  end

  describe 'Anthropic abort_generation' do
    let(:provider) { RubyMCP::Providers::Anthropic.new(api_key: api_key) }
    let(:generation_id) { 'gen_123' }

    it 'raises a provider error since Anthropic does not support abortion' do
      expect { provider.abort_generation(generation_id) }.to raise_error(
        RubyMCP::Errors::ProviderError,
        /Anthropic doesn't support aborting generations/
      )
    end
  end
end
