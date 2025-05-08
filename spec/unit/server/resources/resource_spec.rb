# frozen_string_literal: true

RSpec.describe MCP::Server::Resources::Resource do
  describe 'with static data' do
    let(:name) { 'user.profile' }
    let(:schema) do
      {
        type: 'object',
        properties: {
          id: { type: 'integer' }
        }
      }
    end
    let(:data) do
      {
        name: 'John Doe',
        email: 'john@example.com',
        preferences: {
          theme: 'dark'
        }
      }
    end
    let(:resource) { described_class.new(name, schema, data) }
    
    describe '#initialize' do
      it 'sets name, schema, and data' do
        expect(resource.name).to eq(name)
        expect(resource.schema).to eq(schema)
        expect(resource.instance_variable_get(:@handler)).to eq(data)
      end
    end
    
    describe '#get_data' do
      it 'returns the static data' do
        expect(resource.get_data).to eq(data)
      end
      
      it 'ignores parameters for static data' do
        expect(resource.get_data({ id: 123 })).to eq(data)
      end
    end
  end
  
  describe 'with dynamic data handler' do
    let(:name) { 'users.find' }
    let(:schema) do
      {
        type: 'object',
        properties: {
          id: { type: 'integer' }
        },
        required: ['id']
      }
    end
    let(:handler) do
      ->(params) do
        if params[:id] == 123
          { name: 'John Doe', email: 'john@example.com' }
        else
          { error: 'User not found' }
        end
      end
    end
    let(:resource) { described_class.new(name, schema, handler) }
    
    describe '#initialize' do
      it 'sets name, schema, and handler' do
        expect(resource.name).to eq(name)
        expect(resource.schema).to eq(schema)
        expect(resource.instance_variable_get(:@handler)).to eq(handler)
      end
    end
    
    describe '#get_data' do
      it 'calls the handler with parameters' do
        result = resource.get_data({ id: 123 })
        expect(result).to eq({ name: 'John Doe', email: 'john@example.com' })
      end
      
      it 'returns different results based on parameters' do
        result1 = resource.get_data({ id: 123 })
        result2 = resource.get_data({ id: 456 })
        
        expect(result1).to eq({ name: 'John Doe', email: 'john@example.com' })
        expect(result2).to eq({ error: 'User not found' })
      end
      
      it 'validates parameters if validator is provided' do
        validator = double
        allow(validator).to receive(:validate).with({ id: 123 }).and_return(true)
        allow(validator).to receive(:validate).with({ name: 'John' }).and_raise(MCP::Errors::ValidationError.new('Invalid params'))
        
        resource.instance_variable_set(:@validator, validator)
        
        expect(resource.get_data({ id: 123 })).to eq({ name: 'John Doe', email: 'john@example.com' })
        expect {
          resource.get_data({ name: 'John' })
        }.to raise_error(MCP::Errors::ValidationError)
      end
    end
  end
  
  describe 'with parameters validation' do
    let(:name) { 'users.search' }
    let(:schema) do
      {
        type: 'object',
        properties: {
          query: { type: 'string' },
          limit: { type: 'integer', minimum: 1, maximum: 100 }
        },
        required: ['query']
      }
    end
    let(:handler) { ->(params) { { results: ["User matching #{params[:query]}"] } } }
    
    let(:resource) do
      resource = described_class.new(name, schema, handler)
      resource.instance_variable_set(:@validator, MCP::Validator.new(schema))
      resource
    end
    
    describe '#validate_params' do
      it 'returns true for valid parameters' do
        expect(resource.send(:validate_params, { query: 'John' })).to be(true)
        expect(resource.send(:validate_params, { query: 'John', limit: 10 })).to be(true)
      end
      
      it 'raises ValidationError for missing required parameters' do
        expect {
          resource.send(:validate_params, { limit: 10 })
        }.to raise_error(MCP::Errors::ValidationError)
      end
      
      it 'raises ValidationError for invalid parameter types' do
        expect {
          resource.send(:validate_params, { query: 'John', limit: 'ten' })
        }.to raise_error(MCP::Errors::ValidationError)
      end
      
      it 'raises ValidationError for out-of-range values' do
        expect {
          resource.send(:validate_params, { query: 'John', limit: 101 })
        }.to raise_error(MCP::Errors::ValidationError)
      end
    end
  end
end