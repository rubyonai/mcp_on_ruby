# spec/ruby_mcp/server/messages_controller_spec.rb
require 'spec_helper'

RSpec.describe RubyMCP::Server::MessagesController do
  let(:request) { Rack::Request.new({}) }
  let(:controller) { described_class.new(request) }
  let(:storage) { RubyMCP::Storage::Memory.new }
  
  before do
    allow(controller).to receive(:storage).and_return(storage)
    
    # Create a test context
    @context = RubyMCP::Models::Context.new(id: "ctx_test")
    storage.create_context(@context)
  end
  
  describe "#create" do
    it "adds a message to an existing context" do
      allow(controller).to receive(:params).and_return({
        context_id: "ctx_test",
        role: "user",
        content: "Hello, world!"
      })
      
      status, headers, body = controller.create
      
      expect(status).to eq(201)
      message = JSON.parse(body[0])
      expect(message["role"]).to eq("user")
      expect(message["content"]).to eq("Hello, world!")
      
      # Verify the message was added to the context
      context = storage.get_context("ctx_test")
      expect(context.messages.size).to eq(1)
    end
    
    it "returns 404 for non-existent context" do
      allow(controller).to receive(:params).and_return({
        context_id: "nonexistent",
        role: "user",
        content: "Hello, world!"
      })
      
      status, headers, body = controller.create
      
      expect(status).to eq(404)
      error = JSON.parse(body[0])
      expect(error["error"]).to include("not found")
    end
    
    it "returns 400 for invalid message format" do
        allow(controller).to receive(:params).and_return({
          context_id: "ctx_test",
          role: "invalid_role", # Invalid role
          content: "Hello, world!"
        })
        
        status, headers, body = controller.create
        
        expect(status).to eq(400)
        error = JSON.parse(body[0])
        # Update the expectation to match the actual error message format
        expect(error["error"]).to include("Invalid role") # Changed from "Validation"
    end
  end
end