# frozen_string_literal: true

require_relative "base"

module RubyMCP
  module Storage
    class Memory < Base
      def initialize(options = {})
        super
        @contexts = {}
        @contents = {}
      end

      def create_context(context)
        @contexts[context.id] = context
        context
      end

      def get_context(context_id)
        context = @contexts[context_id]
        raise RubyMCP::Errors::ContextError, "Context not found: #{context_id}" unless context
        context
      end

      def update_context(context)
        @contexts[context.id] = context
        context
      end

      def delete_context(context_id)
        context = get_context(context_id)
        @contexts.delete(context_id)
        @contents.delete(context_id)
        context
      end

      def list_contexts(limit: 100, offset: 0)
        @contexts.values
          .sort_by(&:updated_at)
          .reverse
          .slice(offset, limit) || []
      end

      def add_message(context_id, message)
        context = get_context(context_id)
        context.add_message(message)
        update_context(context)
        message
      end

      def add_content(context_id, content_id, content_data)
        context = get_context(context_id)
        @contents[context_id] ||= {}
        @contents[context_id][content_id] = content_data
        content_id
      end

      def get_content(context_id, content_id)
        context = get_context(context_id)
        contents = @contents[context_id] || {}
        content = contents[content_id]
        raise RubyMCP::Errors::ContentError, "Content not found: #{content_id}" unless content
        content
      end
    end
  end
end