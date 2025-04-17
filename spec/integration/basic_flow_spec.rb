# spec/integration/basic_flow_spec.rb
require 'spec_helper'
require 'rack/test'

RSpec.describe "Basic MCP Flow" do
  include Rack::Test::Methods
  
  let(:app) { RubyMCP::Server::App.new.rack_app }
  
  before do
    # Configure with mock providers
    RubyMCP.configure do |config|
      config.providers = { 
        test: { api_key: "test_key" } 
      }
      config.storage = :memory
    end
    
    # Create a test provider that can be stubbed
    test_provider = double("TestProvider")
    allow(test_provider).to receive(:generate)
      .and_return({ content: "Test response", provider: "test", model: "model", created_at: Time.now.utc.iso8601 })
    
    # Allow the provider to be created
    allow_any_instance_of(RubyMCP::Server::GenerateController).to receive(:get_provider)
      .with("test").and_return(test_provider)
  end
  
  it "creates a context, adds a message, and generates a response" do
    # Step 1: Create a context
    post "/contexts", { messages: [{ role: "system", content: "You are a test assistant." }] }.to_json, { "CONTENT_TYPE" => "application/json" }
    expect(last_response.status).to eq(201)
    
    context = JSON.parse(last_response.body)
    context_id = context["id"]
    expect(context_id).to match(/^ctx_/)
    
    # Step 2: Add a message to the context
    post "/messages", { context_id: context_id, role: "user", content: "Hello" }.to_json, { "CONTENT_TYPE" => "application/json" }
    expect(last_response.status).to eq(201)
    
    # Step 3: Generate a response
    post "/generate", { context_id: context_id, engine_id: "test/model" }.to_json, { "CONTENT_TYPE" => "application/json" }
    expect(last_response.status).to eq(200)
    
    response = JSON.parse(last_response.body)
    expect(response["content"]).to eq("Test response")
  end
end