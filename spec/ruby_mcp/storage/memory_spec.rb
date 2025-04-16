# frozen_string_literal: true

RSpec.describe RubyMCP::Storage::Memory do
    let(:storage) { RubyMCP::Storage::Memory.new }
    
    it "creates and retrieves contexts" do
      context = RubyMCP::Models::Context.new(id: "ctx_test")
      
      storage.create_context(context)
      retrieved = storage.get_context("ctx_test")
      
      expect(retrieved).to eq(context)
    end
    
    it "raises an error for non-existent contexts" do
      expect do
        storage.get_context("ctx_nonexistent")
      end.to raise_error(RubyMCP::Errors::ContextError)
    end
    
    it "updates contexts" do
      context = RubyMCP::Models::Context.new(id: "ctx_test")
      storage.create_context(context)
      
      message = RubyMCP::Models::Message.new(
        role: "user",
        content: "Hello"
      )
      
      context.add_message(message)
      storage.update_context(context)
      
      retrieved = storage.get_context("ctx_test")
      expect(retrieved.messages.size).to eq(1)
    end
    
    it "deletes contexts" do
      context = RubyMCP::Models::Context.new(id: "ctx_test")
      storage.create_context(context)
      
      storage.delete_context("ctx_test")
      
      expect do
        storage.get_context("ctx_test")
      end.to raise_error(RubyMCP::Errors::ContextError)
    end
    
    it "adds messages to contexts" do
      context = RubyMCP::Models::Context.new(id: "ctx_test")
      storage.create_context(context)
      
      message = RubyMCP::Models::Message.new(
        role: "user",
        content: "Hello"
      )
      
      storage.add_message("ctx_test", message)
      
      retrieved = storage.get_context("ctx_test")
      expect(retrieved.messages.size).to eq(1)
      expect(retrieved.messages.first.content).to eq("Hello")
    end
    
    it "adds and retrieves content" do
      context = RubyMCP::Models::Context.new(id: "ctx_test")
      storage.create_context(context)
      
      content_id = "cnt_test"
      content_data = { test: true }
      
      storage.add_content("ctx_test", content_id, content_data)
      
      retrieved = storage.get_content("ctx_test", content_id)
      expect(retrieved).to eq(content_data)
    end
  end