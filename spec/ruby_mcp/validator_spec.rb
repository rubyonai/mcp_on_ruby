# spec/ruby_mcp/validator_spec.rb
require 'spec_helper'

RSpec.describe RubyMCP::Validator do
  describe ".validate_context" do
    it "validates a valid context" do
      params = {
        messages: [
          { role: "system", content: "You are a test assistant." }
        ]
      }
      
      expect(RubyMCP::Validator.validate_context(params)).to be true
    end
    
    it "raises an error for invalid context" do
      params = {
        messages: [
          { role: "invalid_role", content: "Test" }
        ]
      }
      
      expect { RubyMCP::Validator.validate_context(params) }
        .to raise_error(RubyMCP::Errors::ValidationError)
    end
  end
  
  # Similar tests for other validate_* methods
end