# frozen_string_literal: true

RSpec.describe RubyMCP::Client do
    let(:storage) { instance_double(RubyMCP::Storage::Memory) }
    let(:client) { described_class.new(storage) }
  
    describe '#initialize' do
      it 'stores the provided storage instance' do
        expect(client.storage).to eq(storage)
      end
    end
  
    describe '#create_context' do
      it 'creates a new context with the given messages' do
        messages = [{ role: 'user', content: 'Hello' }]
        context = instance_double(RubyMCP::Models::Context)
  
        expect(RubyMCP::Models::Context).to receive(:new).with(messages: messages, metadata: {}).and_return(context)
        expect(storage).to receive(:create_context).with(context).and_return(context)
  
        result = client.create_context(messages)
        expect(result).to eq(context)
      end
    end
  
    describe '#list_contexts' do
      it 'delegates to storage with pagination parameters' do
        contexts = [instance_double(RubyMCP::Models::Context)]
  
        expect(storage).to receive(:list_contexts).with(limit: 10, offset: 0).and_return(contexts)
  
        result = client.list_contexts(limit: 10, offset: 0)
        expect(result).to eq(contexts)
      end
    end
  
    describe '#get_context' do
      it 'retrieves a context by ID' do
        context_id = 'ctx_123'
        context = instance_double(RubyMCP::Models::Context)
  
        expect(storage).to receive(:get_context).with(context_id).and_return(context)
  
        result = client.get_context(context_id)
        expect(result).to eq(context)
      end
    end
  
    describe '#delete_context' do
      it 'deletes a context by ID' do
        context_id = 'ctx_123'
  
        expect(storage).to receive(:delete_context).with(context_id).and_return(true)
  
        result = client.delete_context(context_id)
        expect(result).to eq(true)
      end
    end
  
    describe '#add_message' do
      it 'adds a message to a context' do
        context_id = 'ctx_123'
        role = 'user'
        content = 'Hello'
        message = instance_double(RubyMCP::Models::Message)
  
        expect(RubyMCP::Models::Message).to receive(:new).with(role: role, content: content).and_return(message)
        expect(storage).to receive(:add_message).with(context_id, message).and_return(message)
  
        result = client.add_message(context_id, role, content)
        expect(result).to eq(message)
      end
    end
  end# frozen_string_literal: true

RSpec.describe RubyMCP::Client do
  let(:storage) { instance_double(RubyMCP::Storage::Memory) }
  let(:client) { described_class.new(storage) }

  describe '#initialize' do
    it 'stores the provided storage instance' do
      expect(client.storage).to eq(storage)
    end
  end

  describe '#create_context' do
    it 'creates a new context with the given messages' do
      messages = [{ role: 'user', content: 'Hello' }]
      context = instance_double(RubyMCP::Models::Context)
      
      expect(RubyMCP::Models::Context).to receive(:new).with(messages: messages, metadata: {}).and_return(context)
      expect(storage).to receive(:create_context).with(context).and_return(context)
      
      result = client.create_context(messages)
      expect(result).to eq(context)
    end
  end

  describe '#list_contexts' do
    it 'delegates to storage with pagination parameters' do
      contexts = [instance_double(RubyMCP::Models::Context)]
      
      expect(storage).to receive(:list_contexts).with(limit: 10, offset: 0).and_return(contexts)
      
      result = client.list_contexts(limit: 10, offset: 0)
      expect(result).to eq(contexts)
    end
  end

  describe '#get_context' do
    it 'retrieves a context by ID' do
      context_id = 'ctx_123'
      context = instance_double(RubyMCP::Models::Context)
      
      expect(storage).to receive(:get_context).with(context_id).and_return(context)
      
      result = client.get_context(context_id)
      expect(result).to eq(context)
    end
  end

  describe '#delete_context' do
    it 'deletes a context by ID' do
      context_id = 'ctx_123'
      
      expect(storage).to receive(:delete_context).with(context_id).and_return(true)
      
      result = client.delete_context(context_id)
      expect(result).to eq(true)
    end
  end

  describe '#add_message' do
    it 'adds a message to a context' do
      context_id = 'ctx_123'
      role = 'user'
      content = 'Hello'
      message = instance_double(RubyMCP::Models::Message)
      
      expect(RubyMCP::Models::Message).to receive(:new).with(role: role, content: content).and_return(message)
      expect(storage).to receive(:add_message).with(context_id, message).and_return(message)
      
      result = client.add_message(context_id, role, content)
      expect(result).to eq(message)
    end
  end
end
