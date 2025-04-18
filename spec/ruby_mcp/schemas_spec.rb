# frozen_string_literal: true

# spec/ruby_mcp/schemas_spec.rb
require 'spec_helper'

RSpec.describe RubyMCP::Schemas do
  describe 'ContextSchema' do
    it 'validates a valid context' do
      params = {
        messages: [
          { role: 'system', content: 'You are an assistant' },
          { role: 'user', content: 'Hello' }
        ],
        metadata: { user_id: '123' }
      }

      result = RubyMCP::Schemas::ContextSchema.call(params)
      expect(result).to be_success
    end

    it 'allows optional id' do
      params = {
        id: 'ctx_123',
        messages: []
      }

      result = RubyMCP::Schemas::ContextSchema.call(params)
      expect(result).to be_success
    end
  end

  describe 'MessageSchema' do
    it 'validates a standard message' do
      params = {
        context_id: 'ctx_123',
        role: 'user',
        content: 'Hello'
      }

      result = RubyMCP::Schemas::MessageSchema.call(params)
      expect(result).to be_success
    end

    it 'validates a structured content message' do
      params = {
        context_id: 'ctx_123',
        role: 'user',
        content: [
          { type: 'text', text: 'Look at this document:' },
          { type: 'content_pointer', content_id: 'cnt_123' }
        ]
      }

      result = RubyMCP::Schemas::MessageSchema.call(params)
      expect(result).to be_success
    end

    it 'requires context_id' do
      params = {
        role: 'user',
        content: 'Hello'
      }

      result = RubyMCP::Schemas::MessageSchema.call(params)
      expect(result).not_to be_success
      expect(result.errors[:context_id]).not_to be_empty # Changed from be_present
    end
  end
end
