# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'MCP::Server::Resources::Manager' do
  let(:manager_class) { MCP::Server::Resources::Manager }
  let(:resource_class) { MCP::Server::Resources::Resource }
  let(:template_class) { MCP::Server::Resources::ResourceTemplate }
  let(:manager) { manager_class.new }
  
  describe '#initialize' do
    it 'creates empty resource and template collections' do
      expect(manager.instance_variable_get(:@resources)).to eq({})
      expect(manager.instance_variable_get(:@templates)).to eq({})
    end
    
    it 'initializes the logger' do
      expect(manager.instance_variable_get(:@logger)).to eq(MCP.logger)
    end
  end
  
  describe '#register_resource' do
    let(:resource) do
      resource_class.new(
        'user/profile',
        -> { { name: 'John Doe', email: 'john@example.com' } },
        name: 'User Profile'
      )
    end
    
    it 'registers a resource with the given key' do
      manager.register_resource(resource, 'custom.key')
      
      resources = manager.instance_variable_get(:@resources)
      expect(resources).to have_key('custom.key')
      expect(resources['custom.key']).to eq(resource)
    end
    
    it 'uses the resource URI as the key if not provided' do
      manager.register_resource(resource)
      
      resources = manager.instance_variable_get(:@resources)
      expect(resources).to have_key('user/profile')
      expect(resources['user/profile']).to eq(resource)
    end
    
    it 'raises a ResourceError if a resource with the same key already exists' do
      manager.register_resource(resource)
      
      expect {
        manager.register_resource(resource)
      }.to raise_error(MCP::Errors::ResourceError, /already exists/)
    end
  end
  
  describe '#register_template' do
    let(:template) do
      template_class.new(
        'users/{id}',
        ->(params) { { id: params[:id], name: "User #{params[:id]}" } },
        {
          'type' => 'object',
          'properties' => {
            'id' => { 'type' => 'string' }
          },
          'required' => ['id']
        },
        name: 'User Template'
      )
    end
    
    it 'registers a template with the given key' do
      manager.register_template(template, 'custom.key')
      
      templates = manager.instance_variable_get(:@templates)
      expect(templates).to have_key('custom.key')
      expect(templates['custom.key']).to eq(template)
    end
    
    it 'uses the template URI as the key if not provided' do
      manager.register_template(template)
      
      templates = manager.instance_variable_get(:@templates)
      expect(templates).to have_key('users/{id}')
      expect(templates['users/{id}']).to eq(template)
    end
    
    it 'raises a ResourceError if a template with the same key already exists' do
      manager.register_template(template)
      
      expect {
        manager.register_template(template)
      }.to raise_error(MCP::Errors::ResourceError, /already exists/)
    end
  end
  
  describe '#get_resource' do
    let(:resource) do
      resource_class.new(
        'user/profile',
        -> { { name: 'John Doe', email: 'john@example.com' } }
      )
    end
    
    before do
      manager.register_resource(resource)
    end
    
    it 'returns the resource with the given key' do
      result = manager.get_resource('user/profile')
      expect(result).to eq(resource)
    end
    
    it 'returns nil if no resource exists with the given key' do
      expect(manager.get_resource('nonexistent')).to be_nil
    end
  end
  
  describe '#get_template' do
    let(:template) do
      template_class.new(
        'users/{id}',
        ->(params) { { id: params[:id], name: "User #{params[:id]}" } },
        { 'type' => 'object' }
      )
    end
    
    before do
      manager.register_template(template)
    end
    
    it 'returns the template with the given key' do
      result = manager.get_template('users/{id}')
      expect(result).to eq(template)
    end
    
    it 'returns nil if no template exists with the given key' do
      expect(manager.get_template('nonexistent')).to be_nil
    end
  end
  
  describe '#all_resources' do
    let(:resource1) { resource_class.new('user/profile', -> { {} }) }
    let(:resource2) { resource_class.new('user/settings', -> { {} }) }
    
    before do
      manager.register_resource(resource1)
      manager.register_resource(resource2)
    end
    
    it 'returns all registered resources' do
      resources = manager.all_resources
      
      expect(resources).to be_a(Hash)
      expect(resources).to have_key('user/profile')
      expect(resources).to have_key('user/settings')
      expect(resources['user/profile']).to eq(resource1)
      expect(resources['user/settings']).to eq(resource2)
    end
  end
  
  describe '#all_templates' do
    let(:template1) { template_class.new('users/{id}', ->(params) { {} }, {}) }
    let(:template2) { template_class.new('posts/{id}', ->(params) { {} }, {}) }
    
    before do
      manager.register_template(template1)
      manager.register_template(template2)
    end
    
    it 'returns all registered templates' do
      templates = manager.all_templates
      
      expect(templates).to be_a(Hash)
      expect(templates).to have_key('users/{id}')
      expect(templates).to have_key('posts/{id}')
      expect(templates['users/{id}']).to eq(template1)
      expect(templates['posts/{id}']).to eq(template2)
    end
  end
  
  describe '#read' do
    let(:resource) do
      resource_class.new(
        'user/profile',
        -> { { name: 'John Doe', email: 'john@example.com' } }
      )
    end
    
    let(:template) do
      template_class.new(
        'users/{id}',
        ->(params) { { id: params[:id], name: "User #{params[:id]}" } },
        { 'type' => 'object' }
      )
    end
    
    before do
      manager.register_resource(resource)
      manager.register_template(template)
    end
    
    context 'with a direct resource' do
      it 'reads the resource content' do
        result = manager.read('user/profile')
        expect(result).to eq({ name: 'John Doe', email: 'john@example.com' })
      end
    end
    
    context 'with a template resource' do
      it 'raises an error if the resource does not exist' do
        expect {
          manager.read('nonexistent')
        }.to raise_error(MCP::Errors::ResourceError, /not found/)
      end
    end
  end
  
  describe '#create_resource' do
    it 'creates a resource with the given parameters' do
      handler = -> { { name: 'John Doe', email: 'john@example.com' } }
      
      resource = manager.create_resource(
        'user/profile',
        name: 'User Profile',
        description: 'Get user profile information',
        mime_type: 'application/json',
        tags: ['user', 'profile'],
        &handler
      )
      
      expect(resource).to be_a(resource_class)
      expect(resource.uri).to eq('user/profile')
      expect(resource.name).to eq('User Profile')
      expect(resource.description).to eq('Get user profile information')
      expect(resource.mime_type).to eq('application/json')
      expect(resource.tags).to eq(['user', 'profile'])
      expect(resource.handler).to eq(handler)
    end
  end
  
  describe '#create_template' do
    it 'creates a template with the given parameters' do
      handler = ->(params) { { id: params[:id], name: "User #{params[:id]}" } }
      parameters = {
        'type' => 'object',
        'properties' => {
          'id' => { 'type' => 'string' }
        },
        'required' => ['id']
      }
      
      template = manager.create_template(
        'users/{id}',
        parameters,
        name: 'User Template',
        description: 'Get user by ID',
        tags: ['user'],
        &handler
      )
      
      expect(template).to be_a(template_class)
      expect(template.uri_template).to eq('users/{id}')
      expect(template.name).to eq('User Template')
      expect(template.description).to eq('Get user by ID')
      expect(template.tags).to eq(['user'])
      expect(template.parameters).to eq(parameters)
      expect(template.handler).to eq(handler)
    end
  end
  
  describe '#register_handlers' do
    let(:server) { double('Server') }
    
    it 'registers method handlers on the server' do
      expect(server).to receive(:on_method).with('resources/list')
      expect(server).to receive(:on_method).with('resources/listResourceTemplates')
      expect(server).to receive(:on_method).with('resources/read')
      
      manager.register_handlers(server)
    end
  end
  
  describe '#handle_list_resources' do
    let(:resource1) { resource_class.new('user/profile', -> { {} }) }
    let(:resource2) { resource_class.new('user/settings', -> { {} }) }
    
    before do
      manager.register_resource(resource1)
      manager.register_resource(resource2)
    end
    
    it 'returns a list of all registered resources' do
      result = manager.send(:handle_list_resources)
      
      expect(result).to be_a(Hash)
      expect(result).to have_key(:resources)
      expect(result[:resources]).to be_an(Array)
      expect(result[:resources].length).to eq(2)
      expect(result[:resources].map { |r| r[:uri] }).to contain_exactly('user/profile', 'user/settings')
    end
  end
  
  describe '#handle_list_templates' do
    let(:template1) { template_class.new('users/{id}', ->(params) { {} }, {}) }
    let(:template2) { template_class.new('posts/{id}', ->(params) { {} }, {}) }
    
    before do
      manager.register_template(template1)
      manager.register_template(template2)
    end
    
    it 'returns a list of all registered templates' do
      result = manager.send(:handle_list_templates)
      
      expect(result).to be_a(Hash)
      expect(result).to have_key(:resourceTemplates)
      expect(result[:resourceTemplates]).to be_an(Array)
      expect(result[:resourceTemplates].length).to eq(2)
      expect(result[:resourceTemplates].map { |t| t[:uriTemplate] }).to contain_exactly('users/{id}', 'posts/{id}')
    end
  end
  
  describe '#handle_read' do
    let(:resource) do
      resource_class.new(
        'user/profile',
        -> { { name: 'John Doe', email: 'john@example.com' } },
        mime_type: 'application/json'
      )
    end
    
    before do
      manager.register_resource(resource)
      # Mock the read method for testing
      allow(manager).to receive(:read).and_return({ name: 'John Doe', email: 'john@example.com' })
    end
    
    it 'reads the resource and formats the result' do
      params = { uri: 'user/profile' }
      
      result = manager.send(:handle_read, params)
      
      expect(result).to be_a(Hash)
      expect(result).to have_key(:contents)
    end
    
    it 'handles errors during reading' do
      allow(manager).to receive(:read).and_raise(StandardError.new('Test error'))
      
      expect {
        manager.send(:handle_read, { uri: 'user/profile' })
      }.to raise_error(MCP::Errors::ResourceError, /Test error/)
    end
  end
end