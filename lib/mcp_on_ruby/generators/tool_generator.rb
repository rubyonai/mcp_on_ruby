# frozen_string_literal: true

require 'rails/generators'

module McpOnRuby
  module Generators
    # Generator for creating MCP tools
    class ToolGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      desc "Generate an MCP tool class"

      argument :name, type: :string, desc: "Name of the tool"
      
      class_option :description, type: :string, desc: "Description of the tool"
      class_option :input_schema, type: :hash, default: {}, desc: "JSON Schema for input validation"

      def create_tool_file
        template 'tool.rb', File.join('app/tools', "#{file_name}_tool.rb")
      end

      def create_spec_file
        return unless File.exist?(Rails.root.join('spec'))
        
        template 'tool_spec.rb', File.join('spec/tools', "#{file_name}_tool_spec.rb")
      end

      private

      def tool_name
        name.underscore
      end

      def tool_class_name
        "#{name.camelize}Tool"
      end

      def tool_description
        options[:description] || "#{name.humanize} tool"
      end

      def input_schema_code
        if options[:input_schema].any?
          "input_schema #{options[:input_schema].inspect}"
        else
          "# input_schema({\n    #   type: 'object',\n    #   properties: {\n    #     param: { type: 'string' }\n    #   },\n    #   required: ['param']\n    # })"
        end
      end
    end
  end
end