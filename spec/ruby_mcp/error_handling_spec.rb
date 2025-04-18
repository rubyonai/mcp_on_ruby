# spec/ruby_mcp/error_handling_spec.rb
require 'spec_helper'

RSpec.describe "Error handling" do
  describe "Provider errors" do
    let(:provider) { RubyMCP::Providers::Openai.new(api_key: "test_key") }
    let(:context) { RubyMCP::Models::Context.new }
    
    it "handles rate limiting errors" do
      stub_request(:post, "https://api.openai.com/v1/chat/completions")
        .to_return(
          status: 429,
          headers: {"Content-Type" => "application/json"},
          body: {
            "error" => {
              "message" => "Rate limit exceeded",
              "type" => "rate_limit_exceeded"
            }
          }.to_json
        )
      
      expect { provider.generate(context, {model: "gpt-4"}) }
        .to raise_error(RubyMCP::Errors::ProviderError, /rate limit/i)
    end
    
    it "handles authentication errors" do
      stub_request(:post, "https://api.openai.com/v1/chat/completions")
        .to_return(
          status: 401,
          headers: {"Content-Type" => "application/json"},
          body: {
            "error" => {
              "message" => "Invalid authentication",
              "type": "invalid_auth"
            }
          }.to_json
        )
      
      expect { provider.generate(context, {model: "gpt-4"}) }
        .to raise_error(RubyMCP::Errors::ProviderError, /authentication/i)
    end
  end
  
  describe "Storage errors" do
    let(:storage) { RubyMCP::Storage::Memory.new }
    
    it "handles invalid context ID" do
      expect { storage.get_context("nonexistent") }
        .to raise_error(RubyMCP::Errors::ContextError, /not found/i)
    end
    
    it "handles invalid content ID" do
      context = RubyMCP::Models::Context.new(id: "ctx_test")
      storage.create_context(context)
      
      expect { storage.get_content("ctx_test", "nonexistent") }
        .to raise_error(RubyMCP::Errors::ContentError, /not found/i)
    end
  end
end