# frozen_string_literal: true

module RubyMCP
  module Server
    class ContextsController < BaseController
      def index
        limit = (params[:limit] || 50).to_i
        offset = (params[:offset] || 0).to_i

        contexts = storage.list_contexts(limit: limit, offset: offset)
        ok({ contexts: contexts.map(&:to_h) })
      end

      def show
        context = storage.get_context(params[:id])
        ok(context.to_h)
      rescue RubyMCP::Errors::ContextError => e
        not_found(e.message)
      end

      def create
        # Validate the request
        RubyMCP::Validator.validate_context(params)

        # Create a new context
        messages = []

        # If messages were provided, create message objects
        if params[:messages].is_a?(Array)
          params[:messages].each do |msg|
            messages << RubyMCP::Models::Message.new(
              role: msg[:role],
              content: msg[:content],
              id: msg[:id],
              metadata: msg[:metadata]
            )
          end
        end

        # Create the context
        context = RubyMCP::Models::Context.new(
          id: params[:id],
          messages: messages,
          metadata: params[:metadata]
        )

        # Store the context
        storage.create_context(context)

        created(context.to_h)
      rescue RubyMCP::Errors::ValidationError => e
        bad_request(e.message)
      end

      def destroy
        context_id = params[:id]
        
        begin
          storage.delete_context(context_id)
          ok({ success: true })
        rescue RubyMCP::Errors::ContextError => e
          not_found("Context not found: #{e.message}")
        end
      end
    end
  end
end
