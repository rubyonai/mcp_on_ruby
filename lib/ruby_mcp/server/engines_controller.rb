# frozen_string_literal: true

module RubyMCP
  module Server
    class EnginesController < BaseController
      def index
        engines = []

        RubyMCP.configuration.providers.each do |provider_name, provider_config|
          provider_class = get_provider_class(provider_name)
          next unless provider_class

          provider = provider_class.new(provider_config)
          engines.concat(provider.list_engines)
        end

        ok({ engines: engines.map(&:to_h) })
      end

      private

      def get_provider_class(provider_name)
        class_name = provider_name.to_s.capitalize

        if RubyMCP::Providers.const_defined?(class_name)
          RubyMCP::Providers.const_get(class_name)
        else
          RubyMCP.logger.warn "Provider not found: #{provider_name}"
          nil
        end
      end
    end
  end
end
