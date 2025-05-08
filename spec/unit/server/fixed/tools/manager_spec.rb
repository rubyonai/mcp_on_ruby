# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'MCP::Server::Tools::Manager' do
  let(:manager_class) { MCP::Server::Tools::Manager }
  let(:tool_class) { MCP::Server::Tools::Tool }
  let(:manager) { manager_class.new }
  let(:tool) do
    tool_class.new(
      'calculator.add',
      'Add two numbers',
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
  
  describe '#initialize' do
    it 'creates an empty tools hash' do
      expect(manager.instance_variable_get(:@tools)).to eq({})
    end
    
    it 'initializes the logger' do
      expect(manager.instance_variable_get(:@logger)).to eq(MCP.logger)
    end
  end
  
  describe '#register' do
    it 'registers a tool with the given key' do
      manager.register(tool, 'custom.key')
      
      tools = manager.instance_variable_get(:@tools)
      expect(tools).to have_key('custom.key')
      expect(tools['custom.key']).to eq(tool)
    end
    
    it 'uses the tool name as the key if not provided' do
      manager.register(tool)
      
      tools = manager.instance_variable_get(:@tools)
      expect(tools).to have_key('calculator.add')
      expect(tools['calculator.add']).to eq(tool)
    end
    
    it 'raises a ToolError if a tool with the same key already exists' do
      manager.register(tool)
      
      expect {
        manager.register(tool)
      }.to raise_error(MCP::Errors::ToolError, /already exists/)
    end
  end
  
  describe '#unregister' do
    before do
      manager.register(tool)
    end
    
    it 'unregisters a tool with the given key' do
      unregistered = manager.unregister('calculator.add')
      
      expect(unregistered).to eq(tool)
      expect(manager.instance_variable_get(:@tools)).not_to have_key('calculator.add')
    end
    
    it 'returns nil if no tool exists with the given key' do
      expect(manager.unregister('nonexistent')).to be_nil
    end
  end
  
  describe '#get' do
    before do
      manager.register(tool)
    end
    
    it 'returns the tool with the given key' do
      expect(manager.get('calculator.add')).to eq(tool)
    end
    
    it 'returns nil if no tool exists with the given key' do
      expect(manager.get('nonexistent')).to be_nil
    end
  end
  
  describe '#exists?' do
    before do
      manager.register(tool)
    end
    
    it 'returns true if a tool exists with the given key' do
      expect(manager.exists?('calculator.add')).to be(true)
    end
    
    it 'returns false if no tool exists with the given key' do
      expect(manager.exists?('nonexistent')).to be(false)
    end
  end
  
  describe '#all' do
    before do
      manager.register(tool)
    end
    
    it 'returns all registered tools' do
      tools = manager.all
      
      expect(tools).to be_a(Hash)
      expect(tools).to have_key('calculator.add')
      expect(tools['calculator.add']).to eq(tool)
    end
  end
  
  describe '#execute' do
    before do
      manager.register(tool)
    end
    
    context 'with a valid tool and parameters' do
      it 'executes the tool with the given parameters' do
        allow(tool).to receive(:execute).with({ a: 2, b: 3 }).and_return({ sum: 5 })
        
        result = manager.execute('calculator.add', { a: 2, b: 3 })
        expect(result).to eq({ sum: 5 })
      end
    end
    
    context 'with a nonexistent tool' do
      it 'raises a ToolError' do
        expect {
          manager.execute('nonexistent', {})
        }.to raise_error(MCP::Errors::ToolError, /not found/)
      end
    end
    
    context 'when the tool execution fails' do
      it 'raises a ToolError' do
        allow(tool).to receive(:execute).and_raise(StandardError.new('Test error'))
        
        expect {
          manager.execute('calculator.add', {})
        }.to raise_error(MCP::Errors::ToolError, /Test error/)
      end
    end
  end
  
  describe '#create_tool' do
    it 'creates a tool with the given parameters' do
      handler = ->(params) { { sum: params[:a] + params[:b] } }
      
      tool = manager.create_tool(
        'calculator.add',
        'Add two numbers',
        {
          type: 'object',
          properties: {
            a: { type: 'number' },
            b: { type: 'number' }
          },
          required: ['a', 'b']
        },
        &handler
      )
      
      expect(tool).to be_a(tool_class)
      expect(tool.name).to eq('calculator.add')
      expect(tool.description).to eq('Add two numbers')
      expect(tool.handler).to eq(handler)
    end
  end
  
  describe '#register_handlers' do
    let(:server) { double('Server') }
    
    it 'registers method handlers on the server' do
      expect(server).to receive(:on_method).with('tools/list')
      expect(server).to receive(:on_method).with('tools/call')
      
      manager.register_handlers(server)
    end
  end
  
  describe '#handle_list' do
    before do
      manager.register(tool)
    end
    
    it 'returns a list of all registered tools' do
      result = manager.send(:handle_list)
      
      expect(result).to be_a(Hash)
      expect(result).to have_key(:tools)
      expect(result[:tools]).to be_an(Array)
      expect(result[:tools].length).to eq(1)
      expect(result[:tools].first[:name]).to eq('calculator.add')
    end
  end
  
  describe '#handle_call' do
    before do
      manager.register(tool)
    end
    
    context 'with a valid tool and parameters' do
      it 'executes the tool and formats the result' do
        params = {
          name: 'calculator.add',
          arguments: { a: 2, b: 3 }
        }
        
        allow(tool).to receive(:execute).and_return({ sum: 5 })
        
        result = manager.send(:handle_call, params)
        
        expect(result).to be_a(Hash)
        expect(result[:isError]).to be(false)
        expect(result[:content]).to be_an(Array)
      end
    end
    
    context 'with an error during execution' do
      it 'returns an error response' do
        params = {
          name: 'calculator.add',
          arguments: { a: 2 }
        }
        
        allow(tool).to receive(:execute).and_raise(MCP::Errors::ToolError.new('Test error'))
        
        result = manager.send(:handle_call, params)
        
        expect(result).to be_a(Hash)
        expect(result[:isError]).to be(true)
        expect(result[:content]).to be_an(Array)
        expect(result[:content].first[:type]).to eq('text')
        expect(result[:content].first[:text]).to include('Test error')
      end
    end
  end
  
  describe '#convert_to_content' do
    context 'with a Hash result' do
      it 'converts to JSON if not already in MCP content format' do
        result = { sum: 5 }
        content = manager.send(:convert_to_content, result)
        
        expect(content[:type]).to eq('text')
        expect(content[:text]).to eq('{"sum":5}')
      end
      
      it 'returns as-is if already in MCP content format' do
        result = { type: 'text', text: 'Hello world' }
        content = manager.send(:convert_to_content, result)
        
        expect(content).to eq(result)
      end
    end
    
    context 'with a String result' do
      it 'converts to text content' do
        result = 'Hello world'
        content = manager.send(:convert_to_content, result)
        
        expect(content[:type]).to eq('text')
        expect(content[:text]).to eq('Hello world')
      end
    end
    
    context 'with another type of result' do
      it 'converts to JSON' do
        result = [1, 2, 3]
        content = manager.send(:convert_to_content, result)
        
        expect(content[:type]).to eq('text')
        expect(content[:text]).to eq('[1,2,3]')
      end
    end
  end
end