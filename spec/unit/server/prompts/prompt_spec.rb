# frozen_string_literal: true

RSpec.describe MCP::Server::Prompts::Prompt do
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
  let(:prompt) { described_class.new(name, template, schema) }
  
  describe '#initialize' do
    it 'sets name, template, and schema' do
      expect(prompt.name).to eq(name)
      expect(prompt.instance_variable_get(:@template)).to eq(template)
      expect(prompt.schema).to eq(schema)
    end
    
    it 'accepts template and schema as nil' do
      prompt = described_class.new('simple', 'Hello, world!')
      expect(prompt.name).to eq('simple')
      expect(prompt.instance_variable_get(:@template)).to eq('Hello, world!')
      expect(prompt.schema).to be_nil
    end
  end
  
  describe '#show' do
    context 'with variable replacement' do
      it 'replaces variables in template with parameter values' do
        result = prompt.show({ name: 'John' })
        
        expect(result[:human]).to eq('Hello, my name is John.')
        expect(result[:assistant]).to eq('Nice to meet you, John!')
      end
      
      it 'keeps variables if parameters are not provided' do
        result = prompt.show
        
        expect(result[:human]).to eq('Hello, my name is {{name}}.')
        expect(result[:assistant]).to eq('Nice to meet you, {{name}}!')
      end
      
      it 'keeps variables if not in parameters' do
        result = prompt.show({ other: 'value' })
        
        expect(result[:human]).to eq('Hello, my name is {{name}}.')
        expect(result[:assistant]).to eq('Nice to meet you, {{name}}!')
      end
    end
    
    context 'with parameter validation' do
      before do
        validator = MCP::Validator.new(schema)
        prompt.instance_variable_set(:@validator, validator)
      end
      
      it 'validates parameters if validator is provided' do
        expect {
          prompt.show({})
        }.to raise_error(MCP::Errors::ValidationError)
      end
      
      it 'passes validation with valid parameters' do
        expect {
          prompt.show({ name: 'John' })
        }.not_to raise_error
      end
    end
    
    context 'with complex templates' do
      let(:complex_template) do
        {
          system: "You are a customer service agent.",
          messages: [
            { role: "user", content: "I have a problem with {{product}}." },
            { role: "assistant", content: "I'm sorry to hear about your {{product}} issue." },
            { role: "user", content: "It's not working since {{date}}." }
          ],
          examples: [
            {
              product: "{{product}}",
              solutions: ["try {{solution1}}", "or {{solution2}}"]
            }
          ]
        }
      end
      let(:complex_prompt) { described_class.new('complex', complex_template) }
      
      it 'replaces variables in nested structures' do
        params = {
          product: 'laptop',
          date: 'yesterday',
          solution1: 'restarting',
          solution2: 'updating drivers'
        }
        
        result = complex_prompt.show(params)
        
        expect(result[:messages][0][:content]).to eq('I have a problem with laptop.')
        expect(result[:messages][1][:content]).to eq("I'm sorry to hear about your laptop issue.")
        expect(result[:messages][2][:content]).to eq("It's not working since yesterday.")
        expect(result[:examples][0][:product]).to eq('laptop')
        expect(result[:examples][0][:solutions]).to eq(['try restarting', 'or updating drivers'])
      end
    end
    
    context 'with string template' do
      it 'handles simple string templates' do
        prompt = described_class.new('simple', 'Hello, {{name}}!')
        result = prompt.show({ name: 'World' })
        
        expect(result).to eq('Hello, World!')
      end
    end
    
    context 'with arrays' do
      it 'replaces variables in array items' do
        prompt = described_class.new('array', ['Hello, {{name}}!', 'How are you, {{name}}?'])
        result = prompt.show({ name: 'John' })
        
        expect(result).to eq(['Hello, John!', 'How are you, John?'])
      end
    end
  end
  
  describe '#validate_params' do
    before do
      validator = MCP::Validator.new(schema)
      prompt.instance_variable_set(:@validator, validator)
    end
    
    it 'returns true for valid parameters' do
      expect(prompt.send(:validate_params, { name: 'John' })).to be(true)
    end
    
    it 'raises ValidationError for missing required parameters' do
      expect {
        prompt.send(:validate_params, {})
      }.to raise_error(MCP::Errors::ValidationError)
    end
    
    it 'raises ValidationError for invalid parameter types' do
      expect {
        prompt.send(:validate_params, { name: 123 })
      }.to raise_error(MCP::Errors::ValidationError)
    end
    
    it 'returns true if no validator is provided' do
      prompt.instance_variable_set(:@validator, nil)
      expect(prompt.send(:validate_params, {})).to be(true)
    end
  end
end