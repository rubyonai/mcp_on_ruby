# lib/ruby_mcp/client.rb
# frozen_string_literal: true

module RubyMCP
  class Client
    attr_reader :storage

    def initialize(storage)
      @storage = storage
    end

    def create_context(messages = [], metadata = {})
      context = RubyMCP::Models::Context.new(messages: messages, metadata: metadata)
      storage.create_context(context)
    end

    def list_contexts(limit: 50, offset: 0)
      storage.list_contexts(limit: limit, offset: offset)
    end

    def get_context(context_id)
      storage.get_context(context_id)
    end

    def delete_context(context_id)
      storage.delete_context(context_id)
    end

    def add_message(context_id, role, content)
      message = RubyMCP::Models::Message.new(role: role, content: content)
      storage.add_message(context_id, message)
    end
  end
end
