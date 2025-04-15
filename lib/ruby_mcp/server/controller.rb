# frozen_string_literal: true

require "rack"
require "rack/handler/webrick"

module RubyMCP
  module Server
    class Controller
      def initialize(config = RubyMCP.configuration)
        @config = config
        @app = App.new(config)
      end
      
      def start
        options = {
          Host: @config.server_host,
          Port: @config.server_port
        }
        
        RubyMCP.logger.info "Starting RubyMCP server on #{@config.server_host}:#{@config.server_port}"
        Rack::Handler::WEBrick.run @app.rack_app, **options
      end
      
      def stop
        # Nothing to do here yet, but will be useful if we add more complex server
      end
    end
  end
end