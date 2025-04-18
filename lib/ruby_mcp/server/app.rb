# frozen_string_literal: true

require 'rack'
require 'rack/cors'
require 'json'

module RubyMCP
  module Server
    class App
      attr_reader :config

      def initialize(config = RubyMCP.configuration)
        @config = config
        @router = Router.new
        setup_routes
      end

      def call(env)
        request = Rack::Request.new(env)

        # Handle CORS preflight requests
        return [200, {}, []] if request.request_method == 'OPTIONS'

        # Authenticate if required
        if @config.auth_required && !authenticate(request)
          return [401, { 'Content-Type' => 'application/json' }, [{ error: 'Unauthorized' }.to_json]]
        end

        # Route the request
        response = @router.route(request)

        # Default to 404 if no route matched
        response || [404, { 'Content-Type' => 'application/json' }, [{ error: 'Not found' }.to_json]]
      end

      def rack_app
        app = self

        Rack::Builder.new do
          use Rack::Cors do
            allow do
              origins '*'
              resource '*',
                       headers: :any,
                       methods: %i[get post put delete options]
            end
          end

          run app
        end
      end

      private

      def setup_routes
        @router.add('GET', '/engines', EnginesController, :index)
        @router.add('POST', '/contexts', ContextsController, :create)
        @router.add('GET', '/contexts', ContextsController, :index)
        @router.add('GET', '/contexts/:id', ContextsController, :show)
        @router.add('DELETE', '/contexts/:id', ContextsController, :destroy)
        @router.add('POST', '/messages', MessagesController, :create)
        @router.add('POST', '/generate', GenerateController, :create)
        @router.add('POST', '/generate/stream', GenerateController, :stream)
        @router.add('POST', '/content', ContentController, :create)
        @router.add('GET', '/content/:context_id/:id', ContentController, :show)
      end

      def authenticate(request)
        auth_header = request.env['HTTP_AUTHORIZATION']
        return false unless auth_header

        token = auth_header.split(' ').last
        return false unless token

        begin
          JWT.decode(token, @config.jwt_secret, true, { algorithm: 'HS256' })
          true
        rescue JWT::DecodeError
          false
        end
      end
    end
  end
end
