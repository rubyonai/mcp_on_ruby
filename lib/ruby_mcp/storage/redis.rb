# frozen_string_literal: true

require 'redis'
require 'json'
require_relative 'error'

module RubyMCP
  module Storage
    # Redis-based storage implementation for RubyMCP
    class Redis < Base
      def initialize(options = {})
        super
        @redis = if options[:connection].is_a?(::Redis)
                   options[:connection]
                 elsif options[:connection].is_a?(Hash)
                   ::Redis.new(options[:connection])
                 else
                   ::Redis.new
                 end
        @namespace = options[:namespace] || 'ruby_mcp'
        @ttl = options[:ttl] || 86_400 # Default 1 day TTL in seconds
      end

      # Context management
      def create_context(context)
        # Ensure context has an ID
        context_id = context['id']
        raise Error, 'Context must have an ID' unless context_id

        # Check if context already exists
        raise Error, "Context with ID '#{context_id}' already exists" if get_context(context_id)

        # Store the context
        store_context(context)

        # Add to index with timestamp for ordering
        @redis.zadd(
          contexts_index_key,
          Time.now.to_f,
          context_id
        )

        # Return the created context
        context
      end

      def get_context(context_id)
        # Get the context data
        context_data = @redis.get(context_key(context_id))
        return nil unless context_data

        # Parse the context
        context = JSON.parse(context_data)

        # Get messages if any
        messages = get_messages(context_id)
        context['messages'] = messages if messages.any?

        context
      end

      def update_context(context)
        context_id = context['id']

        # Check if context exists
        raise Error, "Context with ID '#{context_id}' does not exist" unless get_context(context_id)

        # Store the updated context
        store_context(context)

        context
      end

      def delete_context(context_id)
        # Remove from index
        @redis.zrem(contexts_index_key, context_id)

        # Delete context data
        @redis.del(context_key(context_id))

        # Delete messages
        @redis.del(messages_key(context_id))

        # Delete all content (using pattern matching)
        content_pattern = key(['context', context_id, 'content', '*'])
        content_keys = @redis.keys(content_pattern)
        @redis.del(*content_keys) if content_keys.any?

        true
      end

      def list_contexts(limit: 100, offset: 0)
        # Get context IDs from the index, sorted by score (timestamp) descending
        context_ids = @redis.zrevrange(contexts_index_key, offset, offset + limit - 1)

        # Return early if no contexts
        return [] if context_ids.empty?

        # Get each context
        context_ids.map { |id| get_context(id) }.compact
      end

      # Message handling
      def add_message(context_id, message)
        # Ensure context exists
        raise Error, "Context with ID '#{context_id}' does not exist" unless get_context(context_id)

        # Add message to the messages list
        message_json = JSON.generate(message)
        @redis.rpush(messages_key(context_id), message_json)

        # Set TTL on messages key
        @redis.expire(messages_key(context_id), @ttl)

        message
      end

      # Content handling
      def add_content(context_id, content_id, content_data)
        # Ensure context exists
        raise Error, "Context with ID '#{context_id}' does not exist" unless get_context(context_id)

        # Store content
        key = content_key(context_id, content_id)

        # If content is binary or complex, use Base64 encoding
        if content_data.is_a?(String) &&
           (content_data.encoding == Encoding::BINARY || content_data.include?("\0"))
          @redis.set(key, [content_data].pack('m0'))
          @redis.set("#{key}:encoding", 'base64')
        else
          @redis.set(key, content_data)
        end

        # Set TTL
        @redis.expire(key, @ttl)
        @redis.expire("#{key}:encoding", @ttl) if @redis.exists?("#{key}:encoding")

        content_data
      end

      def get_content(context_id, content_id)
        key = content_key(context_id, content_id)
        content = @redis.get(key)
        return nil unless content

        # Check if we need to decode from Base64
        encoding = @redis.get("#{key}:encoding")
        content = content.unpack1('m0') if encoding == 'base64'

        content
      end

      private

      def store_context(context)
        context_id = context['id']

        # Store the context
        context_json = JSON.generate(context)
        @redis.set(context_key(context_id), context_json)

        # Set TTL
        @redis.expire(context_key(context_id), @ttl)
      end

      def get_messages(context_id)
        # Get all messages from the list
        message_jsons = @redis.lrange(messages_key(context_id), 0, -1)

        # Parse each message
        message_jsons.map { |json| JSON.parse(json) }
      end

      # Helper methods for key generation
      def key(parts)
        [@namespace, *parts].join(':')
      end

      def context_key(context_id)
        key(['context', context_id])
      end

      def messages_key(context_id)
        key(['context', context_id, 'messages'])
      end

      def content_key(context_id, content_id)
        key(['context', context_id, 'content', content_id])
      end

      def contexts_index_key
        key(%w[contexts index])
      end
    end
  end
end
