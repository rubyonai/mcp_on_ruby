# frozen_string_literal: true

module RubyMCP
  module Server
    class GenerateController < BaseController
      def create
        context_id = params[:context_id]
        engine_id = params[:engine_id]

        begin
          # Get the context
          context = storage.get_context(context_id)

          # Find the provider
          provider_name, model = parse_engine_id(engine_id)
          provider = get_provider(provider_name)

          # Generation options
          options = {
            model: model,
            max_tokens: params[:max_tokens],
            temperature: params[:temperature],
            top_p: params[:top_p],
            frequency_penalty: params[:frequency_penalty],
            presence_penalty: params[:presence_penalty],
            stop: params[:stop]
          }.compact

          # Generate the response
          response = provider.generate(context, options)

          # Add the assistant message to the context if requested
          if params[:update_context] != false
            message = RubyMCP::Models::Message.new(
              role: 'assistant',
              content: response[:content],
              metadata: response[:metadata]
            )
            storage.add_message(context_id, message)
          end

          ok(response)
        rescue RubyMCP::Errors::ContextError => e
          not_found(e.message)
        rescue RubyMCP::Errors::ProviderError, RubyMCP::Errors::EngineError => e
          bad_request(e.message)
        end
      end

      def stream
        context_id = params[:context_id]
        engine_id = params[:engine_id]

        # Check that we have a streaming-compatible request
        return bad_request('Streaming requires HTTP/1.1 or higher') unless request.env['HTTP_VERSION'] == 'HTTP/1.1'

        begin
          # Get the context
          context = storage.get_context(context_id)

          # Find the provider
          provider_name, model = parse_engine_id(engine_id)
          provider = get_provider(provider_name)

          # Generation options
          options = {
            model: model,
            max_tokens: params[:max_tokens],
            temperature: params[:temperature],
            top_p: params[:top_p],
            frequency_penalty: params[:frequency_penalty],
            presence_penalty: params[:presence_penalty],
            stop: params[:stop]
          }.compact

          # Prepare streaming response
          headers = {
            'Content-Type' => 'text/event-stream',
            'Cache-Control' => 'no-cache',
            'Connection' => 'keep-alive'
          }

          # Start streaming
          chunked_body = Enumerator.new do |yielder|
            complete_message = ''

            # Stream the response
            provider.generate_stream(context, options) do |chunk|
              data = chunk.to_json
              yielder << "data: #{data}\n\n"

              # Accumulate content for final message
              complete_message += chunk[:content] if chunk[:content]
            end

            # Add the complete message to context if requested
            if params[:update_context] != false && !complete_message.empty?
              message = RubyMCP::Models::Message.new(
                role: 'assistant',
                content: complete_message
              )
              storage.add_message(context_id, message)
            end

            # End the stream
            yielder << "data: [DONE]\n\n"
          end

          [200, headers, chunked_body]
        rescue RubyMCP::Errors::ContextError => e
          not_found(e.message)
        rescue RubyMCP::Errors::ProviderError, RubyMCP::Errors::EngineError => e
          bad_request(e.message)
        end
      end

      private

      def parse_engine_id(engine_id)
        parts = engine_id.to_s.split('/', 2)
        raise RubyMCP::Errors::ValidationError, 'Invalid engine_id format' unless parts.length == 2

        parts
      end

      def get_provider(provider_name)
        provider_config = RubyMCP.configuration.providers[provider_name.to_sym]
        raise RubyMCP::Errors::ProviderError, "Provider not configured: #{provider_name}" unless provider_config

        class_name = provider_name.to_s.capitalize
        unless RubyMCP::Providers.const_defined?(class_name)
          raise RubyMCP::Errors::ProviderError, "Provider not found: #{provider_name}"
        end

        provider_class = RubyMCP::Providers.const_get(class_name)
        provider_class.new(provider_config)
      end
    end
  end
end
