# frozen_string_literal: true

RSpec.describe RubyMCP::Models::Message do
    it "creates a message with valid attributes" do
      message = RubyMCP::Models::Message.new(
        role: "user",
        content: "Hello, world!"
      )
      
      expect(message.role).to eq("user")
      expect(message.content).to eq("Hello, world!")
      expect(message.id).to match(/^msg_[a-f0-9]+$/)
    end
    
    it "raises an error for invalid roles" do
      expect do
        RubyMCP::Models::Message.new(
          role: "invalid",
          content: "Hello, world!"
        )
      end.to raise_error(RubyMCP::Errors::ValidationError)
    end
    
    it "converts to a hash correctly" do
      message = RubyMCP::Models::Message.new(
        role: "user",
        content: "Hello, world!",
        id: "msg_test",
        metadata: { test: true }
      )
      
      hash = message.to_h
      expect(hash[:id]).to eq("msg_test")
      expect(hash[:role]).to eq("user")
      expect(hash[:content]).to eq("Hello, world!")
      expect(hash[:metadata]).to eq({ test: true })
    end
  end
  
  RSpec.describe RubyMCP::Models::Context do
    it "creates a context with valid attributes" do
      context = RubyMCP::Models::Context.new
      
      expect(context.id).to match(/^ctx_[a-f0-9]+$/)
      expect(context.messages).to eq([])
      expect(context.content_map).to eq({})
    end
    
    it "adds messages correctly" do
      context = RubyMCP::Models::Context.new
      message = RubyMCP::Models::Message.new(
        role: "user",
        content: "Hello, world!"
      )
      
      context.add_message(message)
      
      expect(context.messages.size).to eq(1)
      expect(context.messages.first).to eq(message)
    end
    
    it "adds content correctly" do
      context = RubyMCP::Models::Context.new
      content_id = "cnt_test"
      content_data = { test: true }
      
      context.add_content(content_id, content_data)
      
      expect(context.get_content(content_id)).to eq(content_data)
    end
    
    it "converts to a hash correctly" do
      context = RubyMCP::Models::Context.new(
        id: "ctx_test",
        metadata: { test: true }
      )
      
      hash = context.to_h
      expect(hash[:id]).to eq("ctx_test")
      expect(hash[:messages]).to eq([])
      expect(hash[:metadata]).to eq({ test: true })
      expect(hash[:created_at]).to be_a(String)
      expect(hash[:updated_at]).to be_a(String)
    end
  end