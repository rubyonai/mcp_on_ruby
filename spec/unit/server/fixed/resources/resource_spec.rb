# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'MCP::Server::Resources::Resource' do
  let(:resource_class) { MCP::Server::Resources::Resource }
  
  describe 'basic resource' do
    let(:uri) { 'user/profile' }
    let(:handler) { -> { { name: 'John Doe', email: 'john@example.com' } } }
    let(:name) { 'User Profile' }
    let(:description) { 'Get user profile information' }
    let(:mime_type) { 'application/json' }
    let(:tags) { ['user', 'profile'] }
    let(:resource) { resource_class.new(uri, handler, name: name, description: description, mime_type: mime_type, tags: tags) }
    
    describe '#initialize' do
      it 'sets resource properties' do
        expect(resource.uri).to eq(uri)
        expect(resource.handler).to eq(handler)
        expect(resource.name).to eq(name)
        expect(resource.description).to eq(description)
        expect(resource.mime_type).to eq(mime_type)
        expect(resource.tags).to eq(tags)
      end
      
      it 'uses defaults for optional properties' do
        resource = resource_class.new(uri, handler)
        
        expect(resource.name).to eq(uri)
        expect(resource.description).to eq('')
        expect(resource.mime_type).to eq('text/plain')
        expect(resource.tags).to eq([])
      end
    end
    
    describe '#to_mcp_resource' do
      it 'returns the MCP resource definition' do
        mcp_resource = resource.to_mcp_resource
        
        expect(mcp_resource[:uri]).to eq(uri)
        expect(mcp_resource[:name]).to eq(name)
        expect(mcp_resource[:description]).to eq(description)
        expect(mcp_resource[:mimeType]).to eq(mime_type)
      end
      
      it 'omits optional properties if not set' do
        resource = resource_class.new(uri, handler)
        mcp_resource = resource.to_mcp_resource
        
        expect(mcp_resource[:uri]).to eq(uri)
        expect(mcp_resource[:name]).to eq(uri)
        expect(mcp_resource[:description]).to eq('')
        expect(mcp_resource[:mimeType]).to eq('text/plain')
      end
    end
    
    describe '#read' do
      it 'calls the handler to get the resource content' do
        result = resource.read
        expect(result).to eq({ name: 'John Doe', email: 'john@example.com' })
      end
    end
    
    describe '.from_method' do
      let(:method_obj) do
        obj = Object.new
        def obj.user_profile
          { name: 'John Doe', email: 'john@example.com' }
        end
        obj.method(:user_profile)
      end
      
      it 'creates a resource from a method' do
        resource = resource_class.from_method(
          method_obj, 
          'user/profile', 
          name: 'User Profile', 
          description: 'Get user profile information', 
          mime_type: 'application/json', 
          tags: ['user', 'profile']
        )
        
        expect(resource.uri).to eq('user/profile')
        expect(resource.name).to eq('User Profile')
        expect(resource.description).to eq('Get user profile information')
        expect(resource.mime_type).to eq('application/json')
        expect(resource.tags).to eq(['user', 'profile'])
        
        # Test handler
        result = resource.read
        expect(result).to eq({ name: 'John Doe', email: 'john@example.com' })
      end
    end
  end
  
  describe 'MCP::Server::Resources::ResourceTemplate' do
    let(:template_class) { MCP::Server::Resources::ResourceTemplate }
    let(:uri_template) { 'users/{id}' }
    let(:handler) { ->(params) { { id: params[:id], name: "User #{params[:id]}" } } }
    let(:parameters) do
      {
        'type' => 'object',
        'properties' => {
          'id' => { 'type' => 'string' }
        },
        'required' => ['id']
      }
    end
    let(:name) { 'User Template' }
    let(:description) { 'Get user by ID' }
    let(:tags) { ['user'] }
    let(:template) { template_class.new(uri_template, handler, parameters, name: name, description: description, tags: tags) }
    
    describe '#initialize' do
      it 'sets template properties' do
        expect(template.uri_template).to eq(uri_template)
        expect(template.handler).to eq(handler)
        expect(template.parameters).to eq(parameters)
        expect(template.name).to eq(name)
        expect(template.description).to eq(description)
        expect(template.tags).to eq(tags)
      end
      
      it 'uses defaults for optional properties' do
        template = template_class.new(uri_template, handler, parameters)
        
        expect(template.name).to eq(uri_template)
        expect(template.description).to eq('')
        expect(template.tags).to eq([])
      end
    end
    
    describe '#to_mcp_template' do
      it 'returns the MCP template definition' do
        mcp_template = template.to_mcp_template
        
        expect(mcp_template[:uriTemplate]).to eq(uri_template)
        expect(mcp_template[:parameters]).to eq(parameters)
        expect(mcp_template[:name]).to eq(name)
        expect(mcp_template[:description]).to eq(description)
      end
      
      it 'omits optional properties if not set' do
        template = template_class.new(uri_template, handler, parameters)
        mcp_template = template.to_mcp_template
        
        expect(mcp_template[:uriTemplate]).to eq(uri_template)
        expect(mcp_template[:parameters]).to eq(parameters)
        expect(mcp_template[:name]).to eq(uri_template)
        expect(mcp_template).not_to have_key(:tags)
      end
    end
    
    describe '#resolve' do
      it 'replaces parameters in the URI template' do
        resolved = template.resolve({ id: '123' })
        expect(resolved).to eq('users/123')
      end
      
      it 'handles multiple parameters' do
        template = template_class.new('users/{id}/posts/{post_id}', handler, parameters)
        resolved = template.resolve({ id: '123', post_id: '456' })
        expect(resolved).to eq('users/123/posts/456')
      end
    end
    
    describe '#read' do
      it 'calls the handler with parameters' do
        result = template.read({ id: '123' })
        expect(result).to eq({ id: '123', name: 'User 123' })
      end
    end
    
    describe '.from_method' do
      let(:method_obj) do
        obj = Object.new
        def obj.get_user(id)
          { id: id, name: "User #{id}" }
        end
        obj.method(:get_user)
      end
      
      before do
        allow(method_obj).to receive(:parameters).and_return([[:req, :id]])
      end
      
      it 'creates a template from a method' do
        template = template_class.from_method(
          method_obj, 
          'users/{id}', 
          name: 'User Template', 
          description: 'Get user by ID', 
          tags: ['user']
        )
        
        expect(template.uri_template).to eq('users/{id}')
        expect(template.name).to eq('User Template')
        expect(template.description).to eq('Get user by ID')
        expect(template.tags).to eq(['user'])
        
        # Validate parameters
        expect(template.parameters['type']).to eq('object')
        expect(template.parameters['required']).to contain_exactly('id')
        expect(template.parameters['properties']).to have_key('id')
        
        # Test handler
        result = template.read({ id: '123' })
        expect(result).not_to be_nil
      end
    end
  end
end