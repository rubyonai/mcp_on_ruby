# frozen_string_literal: true

require 'rails/generators'

module McpOnRuby
  module Generators
    # Generator for creating MCP resources
    class ResourceGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      desc "Generate an MCP resource class"

      argument :name, type: :string, desc: "Name of the resource"
      
      class_option :uri, type: :string, desc: "URI pattern for the resource"
      class_option :description, type: :string, desc: "Description of the resource"
      class_option :mime_type, type: :string, default: 'application/json', desc: "MIME type of the resource"
      class_option :template, type: :boolean, default: false, desc: "Create a templated resource with parameters"

      def create_resource_file
        template 'resource.rb', File.join('app/resources', "#{file_name}_resource.rb")
      end

      def create_spec_file
        return unless File.exist?(Rails.root.join('spec'))
        
        template 'resource_spec.rb', File.join('spec/resources', "#{file_name}_resource_spec.rb")
      end

      private

      def resource_name
        name.underscore
      end

      def resource_class_name
        "#{name.camelize}Resource"
      end

      def resource_uri
        options[:uri] || (options[:template] ? "#{resource_name}/{id}" : resource_name)
      end

      def resource_description
        options[:description] || "#{name.humanize} resource"
      end

      def resource_mime_type
        options[:mime_type]
      end

      def is_template?
        options[:template] || resource_uri.include?('{')
      end

      def template_params
        return [] unless is_template?
        
        resource_uri.scan(/\{([^}]+)\}/).flatten
      end
    end
  end
end