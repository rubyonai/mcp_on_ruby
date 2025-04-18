# frozen_string_literal: true

module RubyMCP
  module Storage
    class Base
      def initialize(options = {})
        @options = options
      end

      def create_context(context)
        raise NotImplementedError, "#{self.class.name} must implement #create_context"
      end

      def get_context(context_id)
        raise NotImplementedError, "#{self.class.name} must implement #get_context"
      end

      def update_context(context)
        raise NotImplementedError, "#{self.class.name} must implement #update_context"
      end

      def delete_context(context_id)
        raise NotImplementedError, "#{self.class.name} must implement #delete_context"
      end

      def list_contexts(limit: 100, offset: 0)
        raise NotImplementedError, "#{self.class.name} must implement #list_contexts"
      end

      def add_message(context_id, message)
        raise NotImplementedError, "#{self.class.name} must implement #add_message"
      end

      def add_content(context_id, content_id, content_data)
        raise NotImplementedError, "#{self.class.name} must implement #add_content"
      end

      def get_content(context_id, content_id)
        raise NotImplementedError, "#{self.class.name} must implement #get_content"
      end
    end
  end
end
