# spec/ruby_mcp/tools_spec.rb
require 'spec_helper'

RSpec.describe "Tool calls functionality" do
  let(:context) { RubyMCP::Models::Context.new(id: "ctx_test") }
  
  describe "OpenAI tool calls" do
    let(:provider) { RubyMCP::Providers::Openai.new(api_key: "test_key") }
    
    before do
      # Add a message to the context
      context.add_message(RubyMCP::Models::Message.new(role: "user", content: "What's the weather?"))
    end
    
    it "handles tool calls in the response" do
      tools = [
        {
          type: "function",
          function: {
            name: "get_weather",
            description: "Get weather information",
            parameters: {
              type: "object",
              properties: {
                location: {
                  type: "string",
                  description: "City name"
                }
              },
              required: ["location"]
            }
          }
        }
      ]
      
      # Mock the API response
      stub_request(:post, "https://api.openai.com/v1/chat/completions")
        .to_return(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: {
            "choices" => [
              {
                "message" => {
                  "tool_calls" => [
                    {
                      "id" => "tc_123",
                      "function" => {
                        "name" => "get_weather",
                        "arguments" => '{"location":"San Francisco"}'
                      }
                    }
                  ]
                }
              }
            ]
          }.to_json
        )
      
      response = provider.generate(context, {model: "gpt-4", tools: tools})
      
      expect(response[:tool_calls]).to be_an(Array)
      expect(response[:tool_calls].first[:type]).to eq("function")
      expect(response[:tool_calls].first[:function][:name]).to eq("get_weather")
      expect(JSON.parse(response[:tool_calls].first[:function][:arguments])).to include("location" => "San Francisco")
    end
  end
end