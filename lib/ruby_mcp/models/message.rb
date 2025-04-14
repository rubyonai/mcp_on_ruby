# frozen_string_literal: true

require "securerandom"

module RubyMCP
  module Models
    class Message
      VALID_ROLES = %w[user assistant system tool].freeze

      attr_reader :id, :role, :content, :created_at
      attr_accessor :metadata

      def initialize(role:, content:, id: nil, metadata: {})
        @id = id || "msg_#{SecureRandom.hex(10)}"
        
        unless VALID_ROLES.include?(role)
          raise RubyMCP::Errors::ValidationError, "Invalid role: #{role}. Must be one of: #{VALID_ROLES.join(', ')}"
        end
        
        @role = role
        @content = content
        @created_at = Time.now.utc
        @metadata = metadata || {}
      end

      def to_h
        {
          id: @id,
          role: @role,
          content: @content,
          created_at: @created_at.iso8601,
          metadata: @metadata
        }
      end

      def content_type
        return "array" if @content.is_a?(Array)
        "text"
      end
      
      def estimated_token_count
        # Very basic estimation, would need to be improved with a real tokenizer
        if @content.is_a?(String)
          @content.split(/\s+/).size
        elsif @content.is_a?(Array)
          @content.sum do |part|
            if part.is_a?(String) || part[:text]
              (part.is_a?(String) ? part : part[:text]).split(/\s+/).size
            else
              10 # Arbitrary count for non-text content
            end
          end
        else
          10 # Default for unknown content format
        end
      end
    end
  end
end