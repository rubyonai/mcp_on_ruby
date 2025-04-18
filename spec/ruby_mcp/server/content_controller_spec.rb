# spec/ruby_mcp/server/content_controller_spec.rb
require 'spec_helper'

RSpec.describe RubyMCP::Server::ContentController do
  let(:request) { Rack::Request.new({}) }
  let(:controller) { described_class.new(request) }
  let(:storage) { RubyMCP::Storage::Memory.new }
  
  before do
    allow(controller).to receive(:storage).and_return(storage)
    
    # Create a test context
    @context = RubyMCP::Models::Context.new(id: "ctx_test")
    storage.create_context(@context)
    
    # Add test content
    storage.add_content("ctx_test", "cnt_test", {
      filename: "test.txt",
      content_type: "text/plain",
      data: "Hello, world!"
    })
  end
  
  describe "#create" do
    it "adds content to an existing context" do
      allow(controller).to receive(:params).and_return({
        context_id: "ctx_test",
        type: "file",
        filename: "example.txt",
        content_type: "text/plain",
        file_data: Base64.strict_encode64("Example content")
      })
      
      status, headers, body = controller.create
      
      expect(status).to eq(201)
      content = JSON.parse(body[0])
      expect(content["context_id"]).to eq("ctx_test")
      expect(content["type"]).to eq("file")
    end
    
    it "returns 404 for non-existent context" do
      allow(controller).to receive(:params).and_return({
        context_id: "nonexistent",
        type: "file",
        filename: "example.txt",
        file_data: Base64.strict_encode64("Example content")
      })
      
      status, headers, body = controller.create
      
      expect(status).to eq(404)
      error = JSON.parse(body[0])
      expect(error["error"]).to include("not found")
    end
  end
  
  describe "#show" do
    it "retrieves content from a context" do
      allow(controller).to receive(:params).and_return({
        context_id: "ctx_test",
        id: "cnt_test"
      })
      
      status, headers, body = controller.show
      
      expect(status).to eq(200)
      # The response format depends on your implementation
      # This test might need adjustment based on how you return content
    end
    
    it "returns 404 for non-existent content" do
      allow(controller).to receive(:params).and_return({
        context_id: "ctx_test",
        id: "nonexistent"
      })
      
      status, headers, body = controller.show
      
      expect(status).to eq(404)
      error = JSON.parse(body[0])
      expect(error["error"]).to include("not found")
    end
  end
end