# spec/ruby_mcp/structured_content_spec.rb
require 'spec_helper'

RSpec.describe "Structured message content" do
  let(:storage) { RubyMCP::Storage::Memory.new }
  
  before do
    # Create a test context
    @context = RubyMCP::Models::Context.new(id: "ctx_test")
    storage.create_context(@context)
    
    # Add a test file
    storage.add_content("ctx_test", "cnt_test", {
      filename: "document.txt",
      content_type: "text/plain",
      data: "This is a test document."
    })
  end
  
  it "creates a message with structured content" do
    message = RubyMCP::Models::Message.new(
      role: "user",
      content: [
        { type: "text", text: "Please analyze this document:" },
        { type: "content_pointer", content_id: "cnt_test" }
      ]
    )
    
    # Add the message to the context
    storage.add_message("ctx_test", message)
    
    # Retrieve the context and verify
    context = storage.get_context("ctx_test")
    expect(context.messages.size).to eq(1)
    expect(context.messages.first.content_type).to eq("array")
    expect(context.messages.first.content.size).to eq(2)
    expect(context.messages.first.content.last[:content_id]).to eq("cnt_test")
  end
  
  it "estimates token count for structured content" do
    message = RubyMCP::Models::Message.new(
      role: "user",
      content: [
        { type: "text", text: "Please analyze this document:" },
        { type: "content_pointer", content_id: "cnt_test" }
      ]
    )
    
    # This test depends on your token counting implementation
    # The key is to verify it handles structured content properly
    expect(message.estimated_token_count).to be > 0
  end
end