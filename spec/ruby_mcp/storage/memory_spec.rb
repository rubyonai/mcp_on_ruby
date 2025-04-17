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

      describe "#list_contexts" do
      it "returns contexts in reverse chronological order" do
        storage = described_class.new
        
        # Create contexts with different timestamps
        context1 = RubyMCP::Models::Context.new(id: "ctx_1")
        context1.instance_variable_set(:@updated_at, Time.now - 60)  # 1 minute ago
        
        context2 = RubyMCP::Models::Context.new(id: "ctx_2")
        context2.instance_variable_set(:@updated_at, Time.now)  # now
        
        storage.create_context(context1)
        storage.create_context(context2)
        
        # List with pagination
        contexts = storage.list_contexts(limit: 10, offset: 0)
        
        # Most recently updated should be first
        expect(contexts.first.id).to eq("ctx_2")
        expect(contexts.last.id).to eq("ctx_1")
      end
      
      it "respects limit and offset parameters" do
        storage = described_class.new
        
        # Create 5 contexts
        5.times do |i|
          storage.create_context(RubyMCP::Models::Context.new(id: "ctx_#{i}"))
        end
        
        # Test pagination
        contexts = storage.list_contexts(limit: 2, offset: 2)
        expect(contexts.size).to eq(2)
      end
    end
  end