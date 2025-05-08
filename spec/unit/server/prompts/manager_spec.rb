# frozen_string_literal: true

RSpec.describe MCP::Server::Prompts::Manager do
  let(:manager) { described_class.new }
  
  describe '#initialize' do
    it 'creates an empty prompts hash' do
      expect(manager.instance_variable_get(:@prompts)).to eq({})
    end
  end
  
  describe '#register' do
    let(:name) { 'greeting' }
    let(:template) do
      {
        system: "You are a helpful assistant.",
        human: "Hello, my name is {{name}}.",
        assistant: "Nice to meet you, {{name}}!"
      }
    end
    let(:schema) do
      {
        type: 'object',
        properties: {
          name: { type: 'string' }
        },
        required: ['name']
      }
    end
    
    it 'registers a prompt with the given name, template, and schema' do
      manager.register(name, template, schema)
      
      prompts = manager.instance_variable_get(:@prompts)
      expect(prompts).to have_key(name)
      expect(prompts[name]).to be_a(MCP::Server::Prompts::Prompt)
    end
    
    it 'overwrites an existing prompt with the same name' do
      manager.register(name, template, schema)
      
      new_template = { human: "What's your favorite color, {{name}}?" }
      manager.register(name, new_template, schema)
      
      prompts = manager.instance_variable_get(:@prompts)
      expect(prompts[name].instance_variable_get(:@template)).to eq(new_template)
    end
  end
  
  describe '#list' do
    before do
      manager.register('prompt1', { human: "Hello {{name}}" }, { type: 'object' })
      manager.register('prompt2', { human: "How are you?" }, { type: 'object' })
    end
    
    it 'returns a list of all registered prompts with their schemas' do
      prompts = manager.list
      
      expect(prompts).to be_an(Array)
      expect(prompts.length).to eq(2)
      expect(prompts.map { |p| p[:name] }).to contain_exactly('prompt1', 'prompt2')
      expect(prompts.first).to include(:name, :schema)
    end
    
    it 'returns an empty array when no prompts are registered' do
      manager = described_class.new
      expect(manager.list).to eq([])
    end
  end
  
  describe '#show' do
    before do
      manager.register('greeting', 
        { human: "Hello, my name is {{name}}." },
        {
          type: 'object',
          properties: { name: { type: 'string' } },
          required: ['name']
        }
      )
    end
    
    it 'returns the processed prompt template with the given name' do
      template = manager.show('greeting', { name: 'John' })
      expect(template).to eq({ human: "Hello, my name is John." })
    end
    
    it 'passes parameters to the prompt for variable replacement' do
      template = manager.show('greeting', { name: 'Jane' })
      expect(template).to eq({ human: "Hello, my name is Jane." })
    end
    
    it 'raises PromptNotFoundError if no prompt exists with the given name' do
      expect {
        manager.show('nonexistent')
      }.to raise_error(MCP::Errors::PromptNotFoundError)
    end
  end
  
  describe '#handle_list_method' do
    before do
      manager.register('prompt1', { human: "Hello {{name}}" }, { type: 'object' })
      manager.register('prompt2', { human: "How are you?" }, { type: 'object' })
    end
    
    it 'returns the list of prompts' do
      result = manager.handle_list_method({})
      
      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
      expect(result.map { |p| p[:name] }).to contain_exactly('prompt1', 'prompt2')
    end
  end
  
  describe '#handle_show_method' do
    before do
      manager.register('greeting', 
        { human: "Hello, my name is {{name}}." },
        {
          type: 'object',
          properties: { name: { type: 'string' } },
          required: ['name']
        }
      )
    end
    
    it 'shows the prompt template with given parameters' do
      params = {
        name: 'greeting',
        parameters: { name: 'John' }
      }
      
      result = manager.handle_show_method(params)
      expect(result).to eq({ human: "Hello, my name is John." })
    end
    
    it 'raises ValidationError if name parameter is missing' do
      expect {
        manager.handle_show_method({ parameters: {} })
      }.to raise_error(MCP::Errors::ValidationError)
    end
    
    it 'raises PromptNotFoundError if prompt does not exist' do
      expect {
        manager.handle_show_method({ name: 'nonexistent', parameters: {} })
      }.to raise_error(MCP::Errors::PromptNotFoundError)
    end
  end
end