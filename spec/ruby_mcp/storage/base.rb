# spec/mocks/ruby_mcp/storage/base.rb
# frozen_string_literal: true

module RubyMCP
  module Storage
    class Error < StandardError; end

    class Base
      def initialize(options = {})
        @options = options
      end

      # Context management
      def create_context(_context)
        raise NotImplementedError, 'Subclasses must implement create_context'
      end

      def get_context(_context_id)
        raise NotImplementedError, 'Subclasses must implement get_context'
      end

      def update_context(_context)
        raise NotImplementedError, 'Subclasses must implement update_context'
      end

      def delete_context(_context_id)
        raise NotImplementedError, 'Subclasses must implement delete_context'
      end

      def list_contexts(limit: 100, offset: 0)
        raise NotImplementedError, 'Subclasses must implement list_contexts'
      end

      # Message handling
      def add_message(_context_id, _message)
        raise NotImplementedError, 'Subclasses must implement add_message'
      end

      # Content handling
      def add_content(_context_id, _content_id, _content_data)
        raise NotImplementedError, 'Subclasses must implement add_content'
      end

      def get_content(_context_id, _content_id)
        raise NotImplementedError, 'Subclasses must implement get_content'
      end
    end
  end
end
