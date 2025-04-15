# frozen_string_literal: true

module RubyMCP
    module Server
      class Router
        Route = Struct.new(:method, :path, :controller, :action)
        
        def initialize
          @routes = []
        end
        
        def add(method, path, controller, action)
          @routes << Route.new(method, path, controller, action)
        end
        
        def route(request)
          route = find_route(request.request_method, request.path)
          return nil unless route
          
          params = extract_params(route.path, request.path)
          
          # Add body params for non-GET requests
          if request.post? || request.put?
            begin
              body_params = JSON.parse(request.body.read, symbolize_names: true)
              params.merge!(body_params)
            rescue JSON::ParserError
              # Handle empty or invalid JSON
            end
          end
          
          # Add query params
          params.merge!(extract_query_params(request))
          
          # Initialize the controller and call the action
          controller = route.controller.new(request, params)
          controller.send(route.action)
        end
        
        private
        
        def find_route(method, path)
          @routes.find do |route|
            route.method == method && path_matches?(route.path, path)
          end
        end
        
        def path_matches?(route_path, request_path)
          route_parts = route_path.split("/")
          request_parts = request_path.split("/")
          
          return false if route_parts.length != request_parts.length
          
          route_parts.zip(request_parts).all? do |route_part, request_part|
            route_part.start_with?(":") || route_part == request_part
          end
        end
        
        def extract_params(route_path, request_path)
          params = {}
          
          route_parts = route_path.split("/")
          request_parts = request_path.split("/")
          
          route_parts.zip(request_parts).each do |route_part, request_part|
            if route_part.start_with?(":")
              param_name = route_part[1..-1].to_sym
              params[param_name] = request_part
            end
          end
          
          params
        end
        
        def extract_query_params(request)
          params = {}
          request.params.each do |key, value|
            params[key.to_sym] = value
          end
          params
        end
      end
    end
  end