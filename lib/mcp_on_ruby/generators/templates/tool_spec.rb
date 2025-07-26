# frozen_string_literal: true

require 'rails_helper'

RSpec.describe <%= tool_class_name %>, type: :model do
  subject(:tool) { described_class.new }

  describe '#execute' do
    let(:arguments) { {} }
    let(:context) { { remote_ip: '127.0.0.1' } }

    it 'executes successfully' do
      result = tool.call(arguments, context)
      
      expect(result).to be_a(Hash)
      expect(result[:success]).to be true
    end

    # Add more specific tests based on your tool's functionality
    # context 'with valid arguments' do
    #   let(:arguments) { { param: 'value' } }
    #   
    #   it 'returns expected result' do
    #     result = tool.call(arguments, context)
    #     
    #     expect(result[:result]).to eq('expected_value')
    #   end
    # end
    
    # context 'with invalid arguments' do
    #   let(:arguments) { { invalid: 'param' } }
    #   
    #   it 'raises validation error' do
    #     expect { tool.call(arguments, context) }.to raise_error(McpOnRuby::ValidationError)
    #   end
    # end
  end

  describe '#authorize' do
    let(:context) { { authenticated: true } }

    it 'returns true for authorized context' do
      expect(tool.authorized?(context)).to be true
    end
  end

  describe '#to_schema' do
    it 'returns valid schema' do
      schema = tool.to_schema
      
      expect(schema).to include(:name, :description, :inputSchema)
      expect(schema[:name]).to eq('<%= tool_name %>')
    end
  end
end