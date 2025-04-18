# frozen_string_literal: true

require 'securerandom'

module RubyMCP
  module Models
    class Context
      attr_reader :id, :messages, :content_map, :created_at, :updated_at
      attr_accessor :metadata

      def initialize(id: nil, messages: [], metadata: {})
        @id = id || "ctx_#{SecureRandom.hex(10)}"
        @messages = messages || []
        @content_map = {}
        @metadata = metadata || {}
        @created_at = Time.now.utc
        @updated_at = @created_at
      end

      def add_message(message)
        @messages << message
        @updated_at = Time.now.utc
        message
      end

      def add_content(content_id, content_data)
        @content_map[content_id] = content_data
        @updated_at = Time.now.utc
        content_id
      end

      def get_content(content_id)
        @content_map[content_id]
      end

      def to_h
        {
          id: @id,
          messages: @messages.map(&:to_h),
          created_at: @created_at.iso8601,
          updated_at: @updated_at.iso8601,
          metadata: @metadata
        }
      end

      def estimated_token_count
        @messages.sum(&:estimated_token_count)
      end
    end
  end
end
