# frozen_string_literal: true

require "json-schema"

module RubyMCP
  class Validator
    def self.validate_context(params)
      schema_path = File.join(File.dirname(__FILE__), "schemas", "context.json")
      validate(params, schema_path)
    end
    
    def self.validate_message(params)
      schema_path = File.join(File.dirname(__FILE__), "schemas", "message.json")
      validate(params, schema_path)
    end
    
    def self.validate_generate(params)
      schema_path = File.join(File.dirname(__FILE__), "schemas", "generate.json")
      validate(params, schema_path)
    end
    
    def self.validate_content(params)
      schema_path = File.join(File.dirname(__FILE__), "schemas", "content.json")
      validate(params, schema_path)
    end
    
    def self.validate(params, schema_path)
      schema = JSON.parse(File.read(schema_path))
      
      begin
        JSON::Validator.validate!(schema, params)
        true
      rescue JSON::Schema::ValidationError => e
        raise RubyMCP::Errors::ValidationError, e.message
      end
    end
  end
end