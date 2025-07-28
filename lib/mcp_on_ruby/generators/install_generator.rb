# frozen_string_literal: true

require 'rails/generators'

module McpOnRuby
  module Generators
    # Generator for installing MCP server in Rails application
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      desc "Install MCP server in Rails application"

      def create_initializer
        template 'initializer.rb', 'config/initializers/mcp_on_ruby.rb'
      end

      def create_application_classes
        template 'application_tool.rb', 'app/tools/application_tool.rb'
        template 'application_resource.rb', 'app/resources/application_resource.rb'
      end

      def create_example_tool
        template 'sample_tool.rb', 'app/tools/sample_tool.rb'
      end

      def create_example_resource
        template 'sample_resource.rb', 'app/resources/sample_resource.rb'
      end

      def add_route
        say "MCP server will be available at /mcp via middleware", :green
        say "No route configuration needed - handled by Railtie", :blue
      end

      def show_readme
        readme 'README' if behavior == :invoke
      end

      private

      def readme(path)
        say IO.read(File.join(self.class.source_root, path)), :green if File.exist?(File.join(self.class.source_root, path))
      end
    end
  end
end