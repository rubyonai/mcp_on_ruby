# frozen_string_literal: true

RSpec.describe MCP::Server::Tools::Tool do
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
  let(:tool) { described_class.new(name, schema, handler) }
  
  describe '#initialize' do
    it 'sets name, schema, and handler' do
      expect(tool.name).to eq(name)
      expect(tool.schema).to eq(schema)
      expect(tool.handler).to eq(handler)
    end
  end
  
  describe '#call' do
    context 'with valid parameters' do
      it 'calls the handler with params' do
        result = tool.call({ a: 2, b: 3 })
        expect(result).to eq({ sum: 5 })
      end
    end
    
    context 'with invalid parameters' do
      it 'raises ValidationError when required params are missing' do
        expect {
          tool.call({ a: 2 })
        }.to raise_error(MCP::Errors::ValidationError)
      end
      
      it 'raises ValidationError when params have wrong type' do
        expect {
          tool.call({ a: 2, b: 'three' })
        }.to raise_error(MCP::Errors::ValidationError)
      end
    end
  end
  
  describe '#validate_params' do
    it 'returns true for valid params' do
      expect(tool.send(:validate_params, { a: 2, b: 3 })).to be(true)
    end
    
    it 'raises ValidationError for invalid params' do
      expect {
        tool.send(:validate_params, { a: 2 })
      }.to raise_error(MCP::Errors::ValidationError)
    end
    
    it 'includes validation details in error message' do
      begin
        tool.send(:validate_params, { a: 2 })
      rescue MCP::Errors::ValidationError => e
        expect(e.message).to include('b')
      end
    end
  end
end