# frozen_string_literal: true

require 'spec_helper'

# Skip these tests if ActiveRecord is not available
begin
  require 'active_record'
  require 'ruby_mcp/storage/active_record'
  ACTIVERECORD_AVAILABLE = true
rescue LoadError
  ACTIVERECORD_AVAILABLE = false
  puts 'Skipping ActiveRecord tests because ActiveRecord is not available'
end

RSpec.describe RubyMCP::Storage::ActiveRecord, if: ACTIVERECORD_AVAILABLE do
  let(:table_prefix) { "test_mcp_#{SecureRandom.hex(4)}_" }
  let(:options) { { table_prefix: table_prefix } }
  let(:storage) { described_class.new(options) }

  # Set up in-memory SQLite database
  before(:all) do
    ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
  end

  # Sample data for testing
  let(:context_id) { 'ctx_123456' }
  let(:context) do
    ctx = RubyMCP::Models::Context.new(id: context_id)
    ctx.metadata[:source] = 'test' # Use symbol keys
    ctx
  end

  let(:message) do
    RubyMCP::Models::Message.new(
      role: 'user',
      content: 'Hello, world!',
      metadata: { timestamp: Time.now.to_i }
    )
  end

  let(:content_id) { 'cnt_123' }
  let(:text_content) { 'Sample content data' }
  let(:binary_content) { String.new("\x00\x01\x02\x03\xFF", encoding: Encoding::BINARY) }
  let(:json_content) { { key1: 'value1', key2: [1, 2, 3] } }

  # Basic functionality tests
  it 'creates, reads, updates, and deletes contexts' do
    # Create a context
    storage.create_context(context)

    # Retrieve the context
    retrieved = storage.get_context(context_id)
    expect(retrieved.id).to eq(context_id)
    expect(retrieved.metadata[:source]).to eq('test')

    # Update the context
    retrieved.metadata[:updated] = true
    storage.update_context(retrieved)

    # Verify the update
    updated = storage.get_context(context_id)
    expect(updated.metadata[:updated]).to be true

    # Delete the context
    expect(storage.delete_context(context_id)).to be true

    # Verify it's deleted
    expect do
      storage.get_context(context_id)
    end.to raise_error(RubyMCP::Errors::ContextError)
  end

  it 'works with messages' do
    # Create a context
    storage.create_context(context)

    # Add a message
    storage.add_message(context_id, message)

    # Verify the message was added
    retrieved = storage.get_context(context_id)
    expect(retrieved.messages.size).to eq(1)
    expect(retrieved.messages.first.role).to eq('user')
    expect(retrieved.messages.first.content).to eq('Hello, world!')
  end

  it 'works with content' do
    # Create a context
    storage.create_context(context)

    # Add text content
    storage.add_content(context_id, content_id, text_content)

    # Verify content was added
    retrieved_content = storage.get_content(context_id, content_id)
    expect(retrieved_content).to eq(text_content)

    # Add JSON content
    json_content_id = 'json_content'
    storage.add_content(context_id, json_content_id, json_content)

    # Verify JSON content
    retrieved_json = storage.get_content(context_id, json_content_id)
    expect(retrieved_json).to be_a(Hash)
    expect(retrieved_json[:key1]).to eq('value1')
    expect(retrieved_json[:key2]).to be_an(Array)
    
    # Add binary content
    binary_content_id = 'binary_content'
    storage.add_content(context_id, binary_content_id, binary_content)
    
    # Verify binary content
    retrieved_binary = storage.get_content(context_id, binary_content_id)
    expect(retrieved_binary).to eq(binary_content)
    expect(retrieved_binary.encoding).to eq(Encoding::ASCII_8BIT) # ActiveRecord preserves binary encoding
    expect(retrieved_binary.b).to eq(binary_content.b) # Compare binary content
  end

  it 'handles errors appropriately' do
    # Context not found error
    expect do
      storage.get_context('nonexistent')
    end.to raise_error(RubyMCP::Errors::ContextError, /not found/)

    # Create a context
    storage.create_context(context)

    # Duplicate context error
    expect do
      storage.create_context(context)
    end.to raise_error(RubyMCP::Errors::ContextError, /exists/)

    # Content not found error
    expect do
      storage.get_content(context_id, 'nonexistent')
    end.to raise_error(RubyMCP::Errors::ContentError, /not found/)
  end

  it 'lists contexts with pagination' do
    # Create multiple contexts
    5.times do |i|
      ctx = RubyMCP::Models::Context.new(id: "ctx_test_#{i}")
      ctx.metadata[:index] = i
      storage.create_context(ctx)
    end

    # Get with default pagination
    contexts = storage.list_contexts
    expect(contexts.size).to eq(5)

    # Get with limit
    contexts = storage.list_contexts(limit: 2)
    expect(contexts.size).to eq(2)

    # Get with offset
    contexts = storage.list_contexts(offset: 3)
    expect(contexts.size).to eq(2)
  end
end
