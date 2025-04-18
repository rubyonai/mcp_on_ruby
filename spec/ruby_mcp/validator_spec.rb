# spec/ruby_mcp/validator_spec.rb
require 'spec_helper'

RSpec.describe RubyMCP::Validator do
  describe ".validate_message" do
    it "validates a valid message" do
      params = {
        context_id: "ctx_123abc",
        role: "user",
        content: "Hello world"
      }
      
      expect(RubyMCP::Validator.validate_message(params)).to be true
    end
    
    it "raises an error for missing required fields" do
      params = {
        context_id: "ctx_123abc",
        # missing role
        content: "Hello world"
      }
      
      expect { RubyMCP::Validator.validate_message(params) }
        .to raise_error(RubyMCP::Errors::ValidationError)
    end
  end
  
  describe ".validate_generate" do
    it "validates a valid generate request" do
      params = {
        context_id: "ctx_123abc",
        engine_id: "openai/gpt-4"
      }
      
      expect(RubyMCP::Validator.validate_generate(params)).to be true
    end
    
    it "validates optional parameters" do
      params = {
        context_id: "ctx_123abc",
        engine_id: "openai/gpt-4",
        max_tokens: 500,
        temperature: 0.7,
        top_p: 0.9
      }
      
      expect(RubyMCP::Validator.validate_generate(params)).to be true
    end
    
    it "raises an error for missing required fields" do
      params = {
        context_id: "ctx_123abc"
        # missing engine_id
      }
      
      expect { RubyMCP::Validator.validate_generate(params) }
        .to raise_error(RubyMCP::Errors::ValidationError)
    end
  end
  
  describe ".validate_content" do
    it "validates a valid content upload" do
      params = {
        context_id: "ctx_123abc",
        type: "file",
        filename: "test.txt",
        file_data: "SGVsbG8gd29ybGQ=" # Base64 for "Hello world"
      }
      
      expect(RubyMCP::Validator.validate_content(params)).to be true
    end
  end
end