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

    def add_message(context_id, role, content, metadata: {})
      message = RubyMCP::Models::Message.new(role: role, content: content, metadata: metadata)
      storage.add_message(context_id, message)
    end

    def add_content(context_id, content_data, content_id = nil)
      content_id ||= "cnt_#{SecureRandom.hex(10)}"
      storage.add_content(context_id, content_id, content_data)
    end

    def get_content(context_id, content_id)
      storage.get_content(context_id, content_id)
    end
  end
end
