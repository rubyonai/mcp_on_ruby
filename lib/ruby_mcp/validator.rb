# frozen_string_literal: true

require_relative 'schemas'

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
        # This converts nested error hashes to strings properly
        error_messages = format_errors(result.errors.to_h)
        raise RubyMCP::Errors::ValidationError, "Validation failed: #{error_messages}"
      end
    end

    def self.format_errors(errors, prefix = '')
      errors.map do |key, value|
        if value.is_a?(Hash)
          format_errors(value, "#{prefix}#{key}.")
        else
          "#{prefix}#{key}: #{Array(value).join(', ')}"
        end
      end.join('; ')
    end
  end
end
