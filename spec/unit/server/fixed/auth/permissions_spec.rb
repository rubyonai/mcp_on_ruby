# frozen_string_literal: true

RSpec.describe "MCP::Server::Auth::Permissions" do
  let(:permissions_class) { MCP::Server::Auth::Permissions }
  let(:permissions) { permissions_class.new }
  
  describe '#initialize' do
    it 'creates an empty method scopes hash' do
      expect(permissions.instance_variable_get(:@method_scopes)).to eq({})
    end
  end
  
  describe '#add_method' do
    it 'adds a method with required scopes' do
      permissions.add_method('tools/list', ['tools:read'])
      
      method_scopes = permissions.instance_variable_get(:@method_scopes)
      expect(method_scopes).to have_key('tools/list')
      expect(method_scopes['tools/list']).to contain_exactly('tools:read')
    end
    
    it 'adds a method with multiple scopes' do
      permissions.add_method('tools/call', ['tools:call', 'tools:write'])
      
      method_scopes = permissions.instance_variable_get(:@method_scopes)
      expect(method_scopes['tools/call']).to contain_exactly('tools:call', 'tools:write')
    end
    
    it 'overwrites existing method scopes' do
      permissions.add_method('tools/list', ['tools:read'])
      permissions.add_method('tools/list', ['tools:list'])
      
      method_scopes = permissions.instance_variable_get(:@method_scopes)
      expect(method_scopes['tools/list']).to contain_exactly('tools:list')
    end
  end
  
  describe '#add_methods' do
    it 'adds multiple methods with their scopes' do
      method_scopes = {
        'tools/list' => ['tools:read'],
        'tools/call' => ['tools:call'],
        'resources/list' => ['resources:read']
      }
      
      permissions.add_methods(method_scopes)
      
      methods = permissions.instance_variable_get(:@method_scopes)
      expect(methods.keys).to contain_exactly('tools/list', 'tools/call', 'resources/list')
      expect(methods['tools/list']).to contain_exactly('tools:read')
      expect(methods['tools/call']).to contain_exactly('tools:call')
      expect(methods['resources/list']).to contain_exactly('resources:read')
    end
  end
  
  describe '#get_required_scopes' do
    before do
      permissions.add_method('tools/list', ['tools:read'])
      permissions.add_method('tools/call', ['tools:call'])
    end
    
    it 'returns the required scopes for a method' do
      scopes = permissions.get_required_scopes('tools/list')
      expect(scopes).to contain_exactly('tools:read')
      
      scopes = permissions.get_required_scopes('tools/call')
      expect(scopes).to contain_exactly('tools:call')
    end
    
    it 'returns nil for methods with no required scopes' do
      scopes = permissions.get_required_scopes('ping')
      expect(scopes).to be_nil
    end
  end
  
  describe '#check_permission' do
    before do
      permissions.add_method('tools/list', ['tools:read'])
      permissions.add_method('tools/call', ['tools:call'])
      permissions.add_method('resources/list', ['resources:read'])
      permissions.add_method('multi/method', ['scope1', 'scope2'])
    end
    
    it 'returns true if method has no required scopes' do
      token = { 'scopes' => ['tools:read'] }
      expect(permissions.check_permission(token, 'ping')).to be(true)
    end
    
    it 'returns true if token has the required scope' do
      token = { 'scopes' => ['tools:read', 'tools:call'] }
      expect(permissions.check_permission(token, 'tools/list')).to be(true)
      expect(permissions.check_permission(token, 'tools/call')).to be(true)
    end
    
    it 'returns false if token does not have the required scope' do
      token = { 'scopes' => ['tools:read'] }
      expect(permissions.check_permission(token, 'tools/call')).to be(false)
      expect(permissions.check_permission(token, 'resources/list')).to be(false)
    end
    
    it 'returns true if token has any of the required scopes' do
      token = { 'scopes' => ['scope1'] }
      expect(permissions.check_permission(token, 'multi/method')).to be(true)
      
      token = { 'scopes' => ['scope2'] }
      expect(permissions.check_permission(token, 'multi/method')).to be(true)
      
      token = { 'scopes' => ['scope1', 'scope2'] }
      expect(permissions.check_permission(token, 'multi/method')).to be(true)
    end
    
    it 'handles nil token' do
      expect(permissions.check_permission(nil, 'tools/list')).to be(false)
    end
    
    it 'handles empty token scopes' do
      token = {}
      expect(permissions.check_permission(token, 'tools/list')).to be(false)
      
      token = { 'scopes' => [] }
      expect(permissions.check_permission(token, 'tools/list')).to be(false)
    end
  end
  
  describe '#load_default_scopes' do
    it 'loads default method scopes' do
      permissions.load_default_scopes
      
      method_scopes = permissions.instance_variable_get(:@method_scopes)
      expect(method_scopes.keys).to include(
        'tools/list', 'tools/call',
        'resources/list', 'resources/get',
        'prompts/list', 'prompts/show',
        'roots/list', 'roots/list_files', 'roots/read_file', 'roots/write_file'
      )
    end
  end
  
  describe '.create_default' do
    it 'creates a permissions manager with default scopes' do
      default_permissions = permissions_class.create_default
      
      method_scopes = default_permissions.instance_variable_get(:@method_scopes)
      expect(method_scopes.keys).to include(
        'tools/list', 'tools/call',
        'resources/list', 'resources/get',
        'prompts/list', 'prompts/show',
        'roots/list', 'roots/list_files', 'roots/read_file', 'roots/write_file'
      )
    end
  end
end