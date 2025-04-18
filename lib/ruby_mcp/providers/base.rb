# frozen_string_literal: true

module RubyMCP
  module Providers
    class Base
      attr_reader :config

      def initialize(config = {})
        @config = config
      end

      def list_engines
        raise NotImplementedError, "#{self.class.name} must implement #list_engines"
      end

      def generate(context, options = {})
        raise NotImplementedError, "#{self.class.name} must implement #generate"
      end

      def generate_stream(context, options = {}, &block)
        raise NotImplementedError, "#{self.class.name} must implement #generate_stream"
      end

      def abort_generation(generation_id)
        raise NotImplementedError, "#{self.class.name} must implement #abort_generation"
      end

      protected

      def api_key
        @config[:api_key] || ENV["#{provider_name.upcase}_API_KEY"]
      end

      def api_base
        @config[:api_base] || default_api_base
      end

      def provider_name
        self.class.name.split('::').last.downcase
      end

      def default_api_base
        raise NotImplementedError, "#{self.class.name} must implement #default_api_base"
      end

      def create_client
        Faraday.new(url: api_base) do |conn|
          conn.request :json
          conn.response :json
          conn.adapter :net_http
          conn.headers['Authorization'] = "Bearer #{api_key}"
          conn.headers['Content-Type'] = 'application/json'
        end
      end
    end
  end
end
