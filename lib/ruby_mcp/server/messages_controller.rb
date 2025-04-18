# frozen_string_literal: true

module RubyMCP
  module Server
    class MessagesController < BaseController
      def create
        context_id = params[:context_id]

        begin
          # Create the message
          message = RubyMCP::Models::Message.new(
            role: params[:role],
            content: params[:content],
            id: params[:id],
            metadata: params[:metadata]
          )

          # Add to the context
          storage.add_message(context_id, message)

          created(message.to_h)
        rescue RubyMCP::Errors::ContextError => e
          not_found(e.message)
        rescue RubyMCP::Errors::ValidationError => e
          bad_request(e.message)
        end
      end
    end
  end
end
