# frozen_string_literal: true

RSpec.describe MCP::Server::Resources::Manager do
  let(:manager) { described_class.new }
  
  describe '#initialize' do
    it 'creates an empty resources hash' do
      expect(manager.instance_variable_get(:@resources)).to eq({})
    end
  end
  
  describe '#register' do
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
        email: 'john@example.com'
      }
    end
    
    it 'registers a resource with static data' do
      manager.register(name, schema, data)
      
      resources = manager.instance_variable_get(:@resources)
      expect(resources).to have_key(name)
      expect(resources[name]).to be_a(MCP::Server::Resources::Resource)
    end
    
    it 'registers a resource with a handler function' do
      handler = ->(params) { { id: params[:id], name: 'John' } }
      manager.register(name, schema, handler)
      
      resources = manager.instance_variable_get(:@resources)
      expect(resources).to have_key(name)
      expect(resources[name].instance_variable_get(:@handler)).to eq(handler)
    end
    
    it 'overwrites an existing resource with the same name' do
      manager.register(name, schema, { name: 'John' })
      
      new_data = { name: 'Jane' }
      manager.register(name, schema, new_data)
      
      resources = manager.instance_variable_get(:@resources)
      expect(resources[name].get_data).to eq(new_data)
    end
  end
  
  describe '#list' do
    before do
      manager.register('resource1', { type: 'object' }, {})
      manager.register('resource2', { type: 'object' }, {})
    end
    
    it 'returns a list of all registered resources with their schemas' do
      resources = manager.list
      
      expect(resources).to be_an(Array)
      expect(resources.length).to eq(2)
      expect(resources.map { |r| r[:name] }).to contain_exactly('resource1', 'resource2')
      expect(resources.first).to include(:name, :schema)
    end
    
    it 'returns an empty array when no resources are registered' do
      manager = described_class.new
      expect(manager.list).to eq([])
    end
  end
  
  describe '#get' do
    before do
      manager.register('user.profile', { type: 'object' }, { name: 'John' })
    end
    
    it 'returns the resource data with the given name' do
      data = manager.get('user.profile')
      expect(data).to eq({ name: 'John' })
    end
    
    it 'passes parameters to the resource' do
      handler = ->(params) { { id: params[:id], name: 'John' } }
      manager.register('users.find', { type: 'object' }, handler)
      
      data = manager.get('users.find', { id: 123 })
      expect(data).to eq({ id: 123, name: 'John' })
    end
    
    it 'raises ResourceNotFoundError if no resource exists with the given name' do
      expect {
        manager.get('nonexistent')
      }.to raise_error(MCP::Errors::ResourceNotFoundError)
    end
  end
  
  describe '#handle_list_method' do
    before do
      manager.register('resource1', { type: 'object' }, {})
      manager.register('resource2', { type: 'object' }, {})
    end
    
    it 'returns the list of resources' do
      result = manager.handle_list_method({})
      
      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
      expect(result.map { |r| r[:name] }).to contain_exactly('resource1', 'resource2')
    end
  end
  
  describe '#handle_get_method' do
    before do
      manager.register('echo', 
        {
          type: 'object',
          properties: {
            message: { type: 'string' }
          },
          required: ['message']
        },
        ->(params) { { message: params[:message] } }
      )
    end
    
    it 'gets the resource and returns the data' do
      params = {
        name: 'echo',
        parameters: { message: 'Hello, world!' }
      }
      
      result = manager.handle_get_method(params)
      expect(result).to eq({ message: 'Hello, world!' })
    end
    
    it 'raises ValidationError if name parameter is missing' do
      expect {
        manager.handle_get_method({ parameters: {} })
      }.to raise_error(MCP::Errors::ValidationError)
    end
    
    it 'raises ResourceNotFoundError if resource does not exist' do
      expect {
        manager.handle_get_method({ name: 'nonexistent', parameters: {} })
      }.to raise_error(MCP::Errors::ResourceNotFoundError)
    end
  end
  
  describe '#handle_stream_method' do
    it 'raises NotImplementedError' do
      expect {
        manager.handle_stream_method({})
      }.to raise_error(NotImplementedError)
    end
  end
end