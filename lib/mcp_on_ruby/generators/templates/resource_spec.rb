# frozen_string_literal: true

require 'rails_helper'

RSpec.describe <%= resource_class_name %>, type: :model do
  subject(:resource) { described_class.new }

  describe '#read' do
    <% if is_template? -%>
    let(:params) { { <%= template_params.map { |p| "'#{p}' => 'test_#{p}'" }.join(', ') %> } }
    <% else -%>
    let(:params) { {} }
    <% end -%>
    let(:context) { { remote_ip: '127.0.0.1' } }

    it 'returns resource content' do
      result = resource.read(params, context)
      
      expect(result).to be_a(Hash)
      expect(result).to have_key(:contents)
      expect(result[:contents]).to be_an(Array)
      
      content = result[:contents].first
      expect(content).to include(:uri, :mimeType, :text)
    end

    <% if is_template? -%>
    it 'uses template parameters' do
      result = resource.read(params, context)
      content = JSON.parse(result[:contents].first[:text])
      
      expect(content['parameters']).to eq(params.stringify_keys)
    end
    <% end -%>
  end

  describe '#authorize' do
    let(:context) { { authenticated: true } }

    it 'returns true for authorized context' do
      expect(resource.authorized?(context)).to be true
    end
  end

  describe '#to_schema' do
    it 'returns valid schema' do
      schema = resource.to_schema
      
      expect(schema).to include(:uri, :mimeType)
      expect(schema[:uri]).to eq('<%= resource_uri %>')
    end
  end

  <% if is_template? -%>
  describe '#template?' do
    it 'returns true' do
      expect(resource.template?).to be true
    end
  end

  describe '#template_params' do
    it 'returns parameter names' do
      expect(resource.template_params).to match_array(<%= template_params.inspect %>)
    end
  end
  <% end -%>
end