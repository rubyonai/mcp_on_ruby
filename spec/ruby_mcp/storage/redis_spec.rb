# frozen_string_literal: true

require 'spec_helper'
require 'ruby_mcp/storage/redis'

RSpec.describe RubyMCP::Storage::Redis do
  let(:redis_client) { instance_double(Redis) }
  let(:namespace) { 'ruby_mcp_test' }
  let(:options) { { connection: redis_client, namespace: namespace, ttl: 3600 } }
  let(:storage) { described_class.new(options) }

  # Sample data for testing
  let(:context_id) { 'ctx_123456' }
  let(:context) do
    {
      'id' => context_id,
      'name' => 'Test Context',
      'metadata' => { 'created_at' => Time.now.iso8601 }
    }
  end

  let(:message) do
    {
      'id' => 'msg_123',
      'role' => 'user',
      'content' => 'Hello, world!',
      'metadata' => { 'timestamp' => Time.now.iso8601 }
    }
  end

  let(:content_id) { 'cont_123' }
  let(:content_data) { 'Sample content data' }
  let(:binary_data) { String.new("\x00\x01\x02\x03\xFF", encoding: Encoding::BINARY) }

  # Allow Redis instance creation with normal options
  before do
    allow(Redis).to receive(:new).and_return(redis_client)

    # Default behavior for get to return nil (key not found)
    allow(redis_client).to receive(:get).and_return(nil)

    # Default behavior for exists? to return false
    allow(redis_client).to receive(:exists?).and_return(false)

    # Allow other Redis methods to be called and return sensible defaults
    allow(redis_client).to receive(:set).and_return('OK')
    allow(redis_client).to receive(:expire).and_return(1)
    allow(redis_client).to receive(:zadd).and_return(1)
    allow(redis_client).to receive(:zrevrange).and_return([])
    allow(redis_client).to receive(:lrange).and_return([])
    allow(redis_client).to receive(:rpush).and_return(1)
    allow(redis_client).to receive(:ttl).and_return(3600)
    allow(redis_client).to receive(:zrem).and_return(1)
    allow(redis_client).to receive(:del).and_return(1)
    allow(redis_client).to receive(:keys).and_return([])
  end

  describe '#initialize' do
    it 'initializes with default options' do
      allow(Redis).to receive(:new).and_return(redis_client)
      storage = described_class.new
      expect(storage.instance_variable_get(:@namespace)).to eq('ruby_mcp')
      expect(storage.instance_variable_get(:@ttl)).to eq(86_400)
    end

    it 'initializes with custom options' do
      expect(storage.instance_variable_get(:@namespace)).to eq(namespace)
      expect(storage.instance_variable_get(:@ttl)).to eq(3600)
    end

    it 'accepts a Redis instance directly' do
      redis = Redis.new
      storage = described_class.new(connection: redis)
      expect(storage.instance_variable_get(:@redis)).to eq(redis)
    end
  end

  describe '#create_context' do
    it 'stores a context' do
      # Mock Redis get to simulate context doesn't exist yet
      expect(redis_client).to receive(:get).with('ruby_mcp_test:context:ctx_123456').and_return(nil)

      # Expect Redis set to be called with JSON-encoded context
      expect(redis_client).to receive(:set).with(
        'ruby_mcp_test:context:ctx_123456',
        kind_of(String)
      )

      # Expect Redis zadd to be called to add to index
      expect(redis_client).to receive(:zadd).with(
        'ruby_mcp_test:contexts:index',
        kind_of(Float),
        'ctx_123456'
      )

      # Expect TTL to be set
      expect(redis_client).to receive(:expire).with(
        'ruby_mcp_test:context:ctx_123456',
        3600
      )

      result = storage.create_context(context)
      expect(result).to eq(context)
    end

    it 'raises an error if context already exists' do
      # Mock Redis get to simulate context already exists
      allow(redis_client).to receive(:get).with('ruby_mcp_test:context:ctx_123456').and_return(context.to_json)

      expect { storage.create_context(context) }.to raise_error(RubyMCP::Storage::Error)
    end
  end

  describe '#get_context' do
    it 'retrieves a stored context' do
      # Mock Redis get to return JSON-encoded context
      allow(redis_client).to receive(:get).with('ruby_mcp_test:context:ctx_123456').and_return(context.to_json)

      # Mock Redis lrange to return empty messages list
      allow(redis_client).to receive(:lrange).with('ruby_mcp_test:context:ctx_123456:messages', 0, -1).and_return([])

      result = storage.get_context(context_id)
      expect(result['id']).to eq(context_id)
      expect(result['name']).to eq('Test Context')
    end

    it 'returns nil for non-existent context' do
      # Mock Redis get to return nil for non-existent context
      allow(redis_client).to receive(:get).with('ruby_mcp_test:context:nonexistent').and_return(nil)

      result = storage.get_context('nonexistent')
      expect(result).to be_nil
    end

    it 'includes messages if they exist' do
      # Mock Redis get to return JSON-encoded context
      allow(redis_client).to receive(:get).with('ruby_mcp_test:context:ctx_123456').and_return(context.to_json)

      # Mock Redis lrange to return messages
      allow(redis_client).to receive(:lrange).with('ruby_mcp_test:context:ctx_123456:messages', 0,
                                                   -1).and_return([message.to_json])

      result = storage.get_context(context_id)
      expect(result['messages'].first['id']).to eq(message['id'])
    end
  end

  describe '#update_context' do
    it 'updates an existing context' do
      # Mock Redis get to simulate context exists
      allow(redis_client).to receive(:get).with('ruby_mcp_test:context:ctx_123456').and_return(context.to_json)
      allow(redis_client).to receive(:lrange).with('ruby_mcp_test:context:ctx_123456:messages', 0, -1).and_return([])

      # Expect Redis set to be called with JSON-encoded updated context
      updated_context = context.merge('name' => 'Updated Context')
      expect(redis_client).to receive(:set).with(
        'ruby_mcp_test:context:ctx_123456',
        kind_of(String)
      )

      # Expect TTL to be set
      expect(redis_client).to receive(:expire).with(
        'ruby_mcp_test:context:ctx_123456',
        3600
      )

      result = storage.update_context(updated_context)
      expect(result).to eq(updated_context)
    end

    it "raises an error if context doesn't exist" do
      # Mock Redis get to simulate context doesn't exist
      allow(redis_client).to receive(:get).with('ruby_mcp_test:context:ctx_123456').and_return(nil)

      expect { storage.update_context(context) }.to raise_error(RubyMCP::Storage::Error)
    end
  end

  describe '#delete_context' do
    it 'removes a context' do
      # Expect Redis zrem to be called to remove from index
      expect(redis_client).to receive(:zrem).with(
        'ruby_mcp_test:contexts:index',
        context_id
      )

      # Expect Redis del to be called to remove context
      expect(redis_client).to receive(:del).with(
        'ruby_mcp_test:context:ctx_123456'
      )

      # Expect Redis del to be called to remove messages
      expect(redis_client).to receive(:del).with(
        'ruby_mcp_test:context:ctx_123456:messages'
      )

      # Expect Redis keys to be called to find content keys
      expect(redis_client).to receive(:keys).with(
        'ruby_mcp_test:context:ctx_123456:content:*'
      ).and_return([])

      expect(storage.delete_context(context_id)).to be true
    end

    it 'removes associated content' do
      # Expect Redis zrem, del for context and messages
      allow(redis_client).to receive(:zrem)
      allow(redis_client).to receive(:del)

      # Expect Redis keys to be called to find content keys
      content_keys = [
        'ruby_mcp_test:context:ctx_123456:content:cont_123',
        'ruby_mcp_test:context:ctx_123456:content:cont_456'
      ]
      expect(redis_client).to receive(:keys).with(
        'ruby_mcp_test:context:ctx_123456:content:*'
      ).and_return(content_keys)

      # Expect Redis del to be called with content keys
      expect(redis_client).to receive(:del).with(*content_keys)

      storage.delete_context(context_id)
    end
  end

  describe '#list_contexts' do
    it 'lists contexts with default limit and offset' do
      # Mock Redis zrevrange to return context IDs
      context_ids = %w[ctx_1 ctx_2 ctx_3]
      allow(redis_client).to receive(:zrevrange).with(
        'ruby_mcp_test:contexts:index', 0, 99
      ).and_return(context_ids)

      # Mock Redis get for each context
      context_ids.each do |id|
        ctx = context.merge('id' => id)
        allow(redis_client).to receive(:get).with("ruby_mcp_test:context:#{id}").and_return(ctx.to_json)
        allow(redis_client).to receive(:lrange).with("ruby_mcp_test:context:#{id}:messages", 0, -1).and_return([])
      end

      results = storage.list_contexts
      expect(results.length).to eq(3)
      expect(results.map { |c| c['id'] }).to eq(context_ids)
    end

    it 'respects limit parameter' do
      # Mock Redis zrevrange to return limited context IDs
      allow(redis_client).to receive(:zrevrange).with(
        'ruby_mcp_test:contexts:index', 0, 1
      ).and_return(%w[ctx_1 ctx_2])

      # Mock Redis get for each context
      %w[ctx_1 ctx_2].each do |id|
        ctx = context.merge('id' => id)
        allow(redis_client).to receive(:get).with("ruby_mcp_test:context:#{id}").and_return(ctx.to_json)
        allow(redis_client).to receive(:lrange).with("ruby_mcp_test:context:#{id}:messages", 0, -1).and_return([])
      end

      results = storage.list_contexts(limit: 2)
      expect(results.length).to eq(2)
    end

    it 'respects offset parameter' do
      # Mock Redis zrevrange to return offset context IDs
      allow(redis_client).to receive(:zrevrange).with(
        'ruby_mcp_test:contexts:index', 2, 4
      ).and_return(%w[ctx_3 ctx_4 ctx_5])

      # Mock Redis get for each context
      %w[ctx_3 ctx_4 ctx_5].each do |id|
        ctx = context.merge('id' => id)
        allow(redis_client).to receive(:get).with("ruby_mcp_test:context:#{id}").and_return(ctx.to_json)
        allow(redis_client).to receive(:lrange).with("ruby_mcp_test:context:#{id}:messages", 0, -1).and_return([])
      end

      results = storage.list_contexts(offset: 2, limit: 3)
      expect(results.length).to eq(3)
      expect(results.map { |c| c['id'] }).to eq(%w[ctx_3 ctx_4 ctx_5])
    end
  end

  describe '#add_message' do
    before do
      # Mock Redis get to simulate context exists
      allow(redis_client).to receive(:get).with('ruby_mcp_test:context:ctx_123456').and_return(context.to_json)
      allow(redis_client).to receive(:lrange).with('ruby_mcp_test:context:ctx_123456:messages', 0, -1).and_return([])
    end

    it 'adds a message to a context' do
      # Expect Redis rpush to be called with JSON-encoded message
      expect(redis_client).to receive(:rpush).with(
        'ruby_mcp_test:context:ctx_123456:messages',
        kind_of(String)
      )

      # Expect TTL to be set
      expect(redis_client).to receive(:expire).with(
        'ruby_mcp_test:context:ctx_123456:messages',
        3600
      )

      result = storage.add_message(context_id, message)
      expect(result).to eq(message)
    end

    it "raises an error if context doesn't exist" do
      # Mock Redis get to simulate context doesn't exist
      allow(redis_client).to receive(:get).with('ruby_mcp_test:context:nonexistent').and_return(nil)

      expect { storage.add_message('nonexistent', message) }.to raise_error(RubyMCP::Storage::Error)
    end
  end

  describe '#add_content' do
    before do
      # Mock Redis get to simulate context exists
      allow(redis_client).to receive(:get).with('ruby_mcp_test:context:ctx_123456').and_return(context.to_json)
      allow(redis_client).to receive(:lrange).with('ruby_mcp_test:context:ctx_123456:messages', 0, -1).and_return([])
    end

    it 'stores content for a context' do
      # Expect Redis set to be called with content
      expect(redis_client).to receive(:set).with(
        'ruby_mcp_test:context:ctx_123456:content:cont_123',
        content_data
      )

      # Expect TTL to be set
      expect(redis_client).to receive(:expire).with(
        'ruby_mcp_test:context:ctx_123456:content:cont_123',
        3600
      )

      result = storage.add_content(context_id, content_id, content_data)
      expect(result).to eq(content_data)
    end

    it 'handles binary data with Base64 encoding' do
      # Expect Redis set to be called with Base64-encoded content
      expect(redis_client).to receive(:set).with(
        'ruby_mcp_test:context:ctx_123456:content:cont_123',
        kind_of(String)
      )

      # Expect Redis set to be called with encoding flag
      expect(redis_client).to receive(:set).with(
        'ruby_mcp_test:context:ctx_123456:content:cont_123:encoding',
        'base64'
      )

      # Expect TTL to be set for content key
      expect(redis_client).to receive(:expire).with(
        'ruby_mcp_test:context:ctx_123456:content:cont_123',
        3600
      )

      # Setup exists? to return true for the encoding key
      allow(redis_client).to receive(:exists?).with(
        'ruby_mcp_test:context:ctx_123456:content:cont_123:encoding'
      ).and_return(true)

      # Expect TTL to be set for encoding key
      expect(redis_client).to receive(:expire).with(
        'ruby_mcp_test:context:ctx_123456:content:cont_123:encoding',
        3600
      )

      result = storage.add_content(context_id, content_id, binary_data)
      expect(result).to eq(binary_data)
    end

    it "raises an error if context doesn't exist" do
      # Mock Redis get to simulate context doesn't exist
      allow(redis_client).to receive(:get).with('ruby_mcp_test:context:nonexistent').and_return(nil)

      expect { storage.add_content('nonexistent', content_id, content_data) }.to raise_error(RubyMCP::Storage::Error)
    end
  end

  describe '#get_content' do
    it 'retrieves stored content' do
      # Mock Redis get to return content
      allow(redis_client).to receive(:get).with('ruby_mcp_test:context:ctx_123456:content:cont_123').and_return(content_data)

      # Mock Redis get to return nil for encoding (not Base64)
      allow(redis_client).to receive(:get).with('ruby_mcp_test:context:ctx_123456:content:cont_123:encoding').and_return(nil)

      result = storage.get_content(context_id, content_id)
      expect(result).to eq(content_data)
    end

    it 'handles Base64-encoded content' do
      encoded_data = [binary_data].pack('m0')

      # Mock Redis get to return Base64-encoded content
      allow(redis_client).to receive(:get).with('ruby_mcp_test:context:ctx_123456:content:cont_123').and_return(encoded_data)

      # Mock Redis get to return encoding flag
      allow(redis_client).to receive(:get).with('ruby_mcp_test:context:ctx_123456:content:cont_123:encoding').and_return('base64')

      result = storage.get_content(context_id, content_id)
      expect(result).to eq(binary_data)
    end

    it 'returns nil for non-existent content' do
      # Mock Redis get to return nil for non-existent content
      allow(redis_client).to receive(:get).with('ruby_mcp_test:context:ctx_123456:content:nonexistent').and_return(nil)

      result = storage.get_content(context_id, 'nonexistent')
      expect(result).to be_nil
    end
  end

  describe 'TTL behavior' do
    it 'sets TTL for context keys' do
      # We already test this in other tests
      expect(redis_client).to receive(:expire).with(
        'ruby_mcp_test:context:ctx_123456',
        3600
      )

      # Mock Redis get to simulate context doesn't exist yet
      allow(redis_client).to receive(:get).with('ruby_mcp_test:context:ctx_123456').and_return(nil)

      # Allow other Redis calls
      allow(redis_client).to receive(:set)
      allow(redis_client).to receive(:zadd)

      storage.create_context(context)
    end
  end
end
