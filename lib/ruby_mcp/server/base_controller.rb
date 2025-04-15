# frozen_string_literal: true

module RubyMCP
    module Server
      class BaseController
        attr_reader :request, :params
        
        def initialize(request, params = {})
          @request = request
          @params = params
        end
        
        protected
        
        def json_response(status, data)
          body = data.to_json
          headers = {
            "Content-Type" => "application/json",
            "Content-Length" => body.bytesize.to_s
          }
          [status, headers, [body]]
        end
        
        def ok(data = {})
          json_response(200, data)
        end
        
        def created(data = {})
          json_response(201, data)
        end
        
        def bad_request(error = "Bad request")
          json_response(400, { error: error })
        end
        
        def not_found(error = "Not found")
          json_response(404, { error: error })
        end
        
        def server_error(error = "Internal server error")
          json_response(500, { error: error })
        end
        
        def storage
          RubyMCP.configuration.storage_instance
        end
      end
    end
  end