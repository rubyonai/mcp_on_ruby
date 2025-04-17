# spec/ruby_mcp/providers/openai_spec.rb
require 'spec_helper'

RSpec.describe RubyMCP::Providers::Openai do
  let(:api_key) { "test_api_key" }
  let(:provider) { described_class.new(api_key: api_key) }
  
  describe "#list_engines" do
    it "fetches models from the OpenAI API" do
      stub_request(:get, "https://api.openai.com/v1/models")
        .with(headers: {"Authorization" => "Bearer test_api_key"})
        .to_return(
          status: 200, 
          headers: {"Content-Type" => "application/json"},
          body: {
            "data" => [
              {"id" => "gpt-4", "object" => "model"},
              {"id" => "gpt-3.5-turbo", "object" => "model"}
            ]
          }.to_json
        )
      
      engines = provider.list_engines
      expect(engines.size).to eq(2)
      expect(engines.first.id).to eq("openai/gpt-4")
      expect(engines.last.id).to eq("openai/gpt-3.5-turbo")
    end
    
    it "handles API errors" do
      stub_request(:get, "https://api.openai.com/v1/models")
        .to_return(
          status: 401, 
          headers: {"Content-Type" => "application/json"},
          body: {
            "error" => {"message" => "Invalid API key"}
          }.to_json
        )
      
      expect { provider.list_engines }.to raise_error(RubyMCP::Errors::ProviderError)
    end
  end
  
  describe "#generate" do
    let(:context) do
      RubyMCP::Models::Context.new.tap do |ctx|
        ctx.add_message(RubyMCP::Models::Message.new(role: "user", content: "Hello"))
      end
    end
    
    it "generates a response from the OpenAI API" do
      stub_request(:post, "https://api.openai.com/v1/chat/completions")
        .with(
          headers: {"Authorization" => "Bearer test_api_key"},
          body: hash_including({
            "model" => "gpt-4",
            "messages" => array_including(hash_including({"role" => "user"}))
          })
        )
        .to_return(
          status: 200, 
          headers: {"Content-Type" => "application/json"},
          body: {
            "choices" => [{"message" => {"content" => "Hi there!"}}]
          }.to_json
        )
      
      response = provider.generate(context, {model: "gpt-4"})
      expect(response[:content]).to eq("Hi there!")
    end
    
    it "handles API errors during generation" do
      stub_request(:post, "https://api.openai.com/v1/chat/completions")
        .to_return(
          status: 429,
          headers: {"Content-Type" => "application/json"},
          body: {
            "error" => {"message" => "Rate limit exceeded"}
          }.to_json
        )
      
      expect { provider.generate(context, {model: "gpt-4"}) }.to raise_error(RubyMCP::Errors::ProviderError)
    end
  end
  
  # Additional tests for streaming, abort_generation, etc.
end