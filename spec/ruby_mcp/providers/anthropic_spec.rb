# spec/ruby_mcp/providers/anthropic_spec.rb
require 'spec_helper'

RSpec.describe RubyMCP::Providers::Anthropic do
  let(:api_key) { "test_api_key" }
  let(:provider) { described_class.new(api_key: api_key) }
  
  describe "#list_engines" do
    it "returns a list of available Anthropic models" do
      engines = provider.list_engines
      expect(engines).to all(be_a(RubyMCP::Models::Engine))
      expect(engines.map(&:provider)).to all(eq("anthropic"))
      
      # Check that it includes known Claude models
      model_ids = engines.map(&:model)
      expect(model_ids).to include("claude-3-opus-20240229")
      expect(model_ids).to include("claude-3-sonnet-20240229")
    end
  end
  
  describe "#generate" do
    let(:context) do
      RubyMCP::Models::Context.new.tap do |ctx|
        ctx.add_message(RubyMCP::Models::Message.new(role: "user", content: "Hello"))
      end
    end
    
    it "generates a response from the Anthropic API" do
      stub_request(:post, "https://api.anthropic.com/v1/messages")
        .with(
          headers: {
            "Anthropic-Version" => "2023-06-01",
            "Content-Type" => "application/json",
            "Authorization" => "Bearer test_api_key"
          }
        )
        .to_return(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: {
            "content" => [{"text" => "Hello there!", "type" => "text"}]
          }.to_json
        )
      
      response = provider.generate(context, {model: "claude-3-opus-20240229"})
      expect(response[:content]).to eq("Hello there!")
    end
    
    it "handles tool calls in the response" do
      stub_request(:post, "https://api.anthropic.com/v1/messages")
        .to_return(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: {
            "tool_calls" => [
              {
                "id" => "tc_123",
                "name" => "weather",
                "input" => "{\"location\":\"San Francisco\"}"
              }
            ]
          }.to_json
        )
      
      response = provider.generate(context, {model: "claude-3-opus-20240229"})
      expect(response[:tool_calls]).to be_an(Array)
      expect(response[:tool_calls].first[:function][:name]).to eq("weather")
    end
  end
end