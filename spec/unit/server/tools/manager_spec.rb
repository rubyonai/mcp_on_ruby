# frozen_string_literal: true

RSpec.describe MCP::Server::Tools::Manager do
  let(:manager) { described_class.new }
  
  describe '#initialize' do
    it 'creates an empty tools hash' do
      expect(manager.instance_variable_get(:@tools)).to eq({})
    end
  end
  
  describe '#register' do
    let(:name) { 'calculator.add' }
    let(:schema) do
      {
        type: 'object',
        properties: {
          a: { type: 'number' },
          b: { type: 'number' }
        },
        required: ['a', 'b']
      }
    end
    let(:handler) { ->(params) { { sum: params[:a] + params[:b] } } }
    
    it 'registers a tool with the given name, schema, and handler' do
      manager.register(name, schema, handler)
      
      tools = manager.instance_variable_get(:@tools)
      expect(tools).to have_key(name)
      expect(tools[name]).to be_a(MCP::Server::Tools::Tool)
    end
    
    it 'overwrites an existing tool with the same name' do
      manager.register(name, schema, handler)
      
      new_handler = ->(params) { { result: params[:a] * params[:b] } }
      manager.register(name, schema, new_handler)
      
      tools = manager.instance_variable_get(:@tools)
      expect(tools[name].handler).to eq(new_handler)
    end
  end
  
  describe '#list' do
    before do
      manager.register('tool1', { type: 'object' }, ->(_) {})
      manager.register('tool2', { type: 'object' }, ->(_) {})
    end
    
    it 'returns a list of all registered tools with their schemas' do
      tools = manager.list
      
      expect(tools).to be_an(Array)
      expect(tools.length).to eq(2)
      expect(tools.map { |t| t[:name] }).to contain_exactly('tool1', 'tool2')
      expect(tools.first).to include(:name, :schema)
    end
    
    it 'returns an empty array when no tools are registered' do
      manager = described_class.new
      expect(manager.list).to eq([])
    end
  end
  
  describe '#get' do
    before do
      manager.register('tool1', { type: 'object' }, ->(_) {})
    end
    
    it 'returns the tool with the given name' do
      tool = manager.get('tool1')
      expect(tool).to be_a(MCP::Server::Tools::Tool)
      expect(tool.name).to eq('tool1')
    end
    
    it 'returns nil if no tool exists with the given name' do
      expect(manager.get('nonexistent')).to be_nil
    end
  end
  
  describe '#call' do
    before do
      manager.register('calculator.add', 
        {
          type: 'object',
          properties: {
            a: { type: 'number' },
            b: { type: 'number' }
          },
          required: ['a', 'b']
        },
        ->(params) { { sum: params[:a] + params[:b] } }
      )
    end
    
    it 'calls the tool with the given name and parameters' do
      result = manager.call('calculator.add', { a: 2, b: 3 })
      expect(result).to eq({ sum: 5 })
    end
    
    it 'raises ToolNotFoundError if no tool exists with the given name' do
      expect {
        manager.call('nonexistent', {})
      }.to raise_error(MCP::Errors::ToolNotFoundError)
    end
    
    it 'propagates ValidationError for invalid parameters' do
      expect {
        manager.call('calculator.add', { a: 2 })
      }.to raise_error(MCP::Errors::ValidationError)
    end
  end
  
  describe '#handle_list_method' do
    before do
      manager.register('tool1', { type: 'object' }, ->(_) {})
      manager.register('tool2', { type: 'object' }, ->(_) {})
    end
    
    it 'returns the list of tools' do
      result = manager.handle_list_method({})
      
      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
      expect(result.map { |t| t[:name] }).to contain_exactly('tool1', 'tool2')
    end
  end
  
  describe '#handle_call_method' do
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
    
    it 'calls the tool and returns the result' do
      params = {
        name: 'echo',
        parameters: { message: 'Hello, world!' }
      }
      
      result = manager.handle_call_method(params)
      expect(result).to eq({ message: 'Hello, world!' })
    end
    
    it 'raises ValidationError if name parameter is missing' do
      expect {
        manager.handle_call_method({ parameters: {} })
      }.to raise_error(MCP::Errors::ValidationError)
    end
    
    it 'raises ToolNotFoundError if tool does not exist' do
      expect {
        manager.handle_call_method({ name: 'nonexistent', parameters: {} })
      }.to raise_error(MCP::Errors::ToolNotFoundError)
    end
    
    it 'forwards validation errors from the tool' do
      expect {
        manager.handle_call_method({ name: 'echo', parameters: {} })
      }.to raise_error(MCP::Errors::ValidationError)
    end
  end
end