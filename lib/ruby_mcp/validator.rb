# frozen_string_literal: true

require_relative "schemas"

module RubyMCP
  class Validator
    def self.validate_context(params)
      validate(params, Schemas::ContextSchema)
    end
    
    def self.validate_message(params)
      validate(params, Schemas::MessageSchema)
    end
    
    def self.validate_generate(params)
      validate(params, Schemas::GenerateSchema)
    end
    
    def self.validate_content(params)
      validate(params, Schemas::ContentSchema)
    end
    
    def self.validate(params, schema)
      result = schema.call(params)
      
      if result.success?
        true
      else
        error_messages = result.errors.to_h.map do |key, messages|
          "#{key}: #{messages.join(', ')}"
        end.join('; ')
        
        raise RubyMCP::Errors::ValidationError, "Validation failed: #{error_messages}"
      end
    end
  end
end