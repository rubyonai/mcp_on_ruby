# spec/ruby_mcp/server/contexts_controller_spec.rb
require 'spec_helper'

RSpec.describe RubyMCP::Server::ContextsController do
  let(:request) { Rack::Request.new({}) }
  let(:controller) { described_class.new(request) }
  
  describe "#create" do
    it "creates a new context" do
      allow(controller).to receive(:params).and_return({
        messages: [{ role: "system", content: "You are a helpful assistant." }]
      })
      
      status, headers, body = controller.create
      
      expect(status).to eq(201)
      context = JSON.parse(body[0])
      expect(context["id"]).to match(/^ctx_/)
      expect(context["messages"].first["role"]).to eq("system")
    end
  end
  
  describe "#show" do
    it "returns a specific context" do
      storage = RubyMCP::Storage::Memory.new
      context = RubyMCP::Models::Context.new(id: "ctx_test")
      storage.create_context(context)
      
      allow(controller).to receive(:params).and_return({ id: "ctx_test" })
      allow(controller).to receive(:storage).and_return(storage)
      
      status, headers, body = controller.show
      
      expect(status).to eq(200)
      context_data = JSON.parse(body[0])
      expect(context_data["id"]).to eq("ctx_test")
    end
    
    it "returns 404 for non-existent context" do
      allow(controller).to receive(:params).and_return({ id: "nonexistent" })
      
      status, headers, body = controller.show
      
      expect(status).to eq(404)
      error = JSON.parse(body[0])
      expect(error["error"]).to include("not found")
    end
  end
end