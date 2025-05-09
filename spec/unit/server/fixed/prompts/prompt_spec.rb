# frozen_string_literal: true

RSpec.describe "MCP::Server::Prompts::Prompt" do
  let(:prompt_class) { MCP::Server::Prompts::Prompt }
  let(:name) { 'greeting' }
  let(:handler) { ->(params) { { role: "assistant", content: "Hello, #{params[:name]}!" } } }
  let(:parameters) do
    {
      "type" => "object",
      "required" => ["name"],
      "properties" => {
        "name" => { "type" => "string" }
      }
    }
  end
  let(:description) { "A friendly greeting prompt" }
  let(:tags) { ["greeting", "friendly"] }
  let(:prompt) { prompt_class.new(name, handler, parameters: parameters, description: description, tags: tags) }
  
  describe '#initialize' do
    it 'sets name, handler, parameters, description, and tags' do
      expect(prompt.name).to eq(name)
      expect(prompt.handler).to eq(handler)
      expect(prompt.parameters).to eq(parameters)
      expect(prompt.description).to eq(description)
      expect(prompt.tags).to eq(tags)
    end
    
    it 'sets defaults for optional parameters' do
      simple_prompt = prompt_class.new(name, handler)
      expect(simple_prompt.name).to eq(name)
      expect(simple_prompt.handler).to eq(handler)
      expect(simple_prompt.parameters).to be_nil
      expect(simple_prompt.description).to eq("")
      expect(simple_prompt.tags).to eq([])
    end
  end
  
  describe '#to_mcp_prompt' do
    it 'returns a hash with prompt information' do
      result = prompt.to_mcp_prompt
      
      expect(result).to be_a(Hash)
      expect(result[:name]).to eq(name)
      expect(result[:description]).to eq(description)
      expect(result[:parameters]).to eq(parameters)
    end
    
    it 'excludes parameters if nil' do
      simple_prompt = prompt_class.new(name, handler)
      result = simple_prompt.to_mcp_prompt
      
      expect(result.keys).not_to include(:parameters)
    end
  end
  
  describe '#render' do
    it 'calls the handler with provided parameters' do
      result = prompt.render({ name: "John" })
      
      expect(result).to eq({ role: "assistant", content: "Hello, John!" })
    end
    
    it 'calls the handler with empty parameters if none are provided' do
      # Create a prompt with a handler that doesn't use parameters
      test_prompt = prompt_class.new("test", ->(_) { "static result" })
      result = test_prompt.render
      
      expect(result).to eq("static result")
    end
  end
  
  describe '.from_method' do
    let(:test_class) do
      Class.new do
        def greeting(name, title = "Mr.")
          "Hello, #{title} #{name}!"
        end
      end
    end
    let(:instance) { test_class.new }
    let(:method) { instance.method(:greeting) }
    
    it 'creates a prompt from a method' do
      prompt = prompt_class.from_method(method, description: "A greeting method")
      
      expect(prompt).to be_a(prompt_class)
      expect(prompt.name).to eq(:greeting)
      expect(prompt.description).to eq("A greeting method")
    end
    
    it 'extracts required and optional parameters from the method' do
      prompt = prompt_class.from_method(method)
      
      expect(prompt.parameters).to be_a(Hash)
      expect(prompt.parameters["properties"]).to be_a(Hash)
    end
    
    it 'creates a handler that calls the method' do
      # Mock the method to avoid actual method call
      allow(method).to receive(:call).and_return("Hello, Dr. John!")
      
      prompt = prompt_class.from_method(method)
      result = prompt.render({ name: "John", title: "Dr." })
      
      expect(result).to eq("Hello, Dr. John!")
    end
    
    it 'accepts a custom name' do
      prompt = prompt_class.from_method(method, name: "custom_greeting")
      
      expect(prompt.name).to eq("custom_greeting")
    end
  end
end