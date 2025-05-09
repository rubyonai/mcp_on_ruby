# frozen_string_literal: true

RSpec.describe "MCP::Server::Roots::Manager" do
  let(:manager_class) { MCP::Server::Roots::Manager }
  let(:root_class) { MCP::Server::Roots::Root }
  let(:manager) { manager_class.new }
  let(:temp_dir) { Dir.mktmpdir }
  let(:logger) { instance_double("Logger", debug: nil, error: nil) }
  
  before do
    # Mock logger
    allow(MCP).to receive(:logger).and_return(logger)
  end
  
  after do
    FileUtils.remove_entry(temp_dir)
  end
  
  describe '#initialize' do
    it 'creates an empty roots hash' do
      expect(manager.instance_variable_get(:@roots)).to eq({})
    end
    
    it 'initializes with logger' do
      expect(manager.instance_variable_get(:@logger)).to eq(logger)
    end
  end
  
  describe '#register' do
    let(:name) { 'test_root' }
    let(:root) do
      instance_double(
        root_class,
        name: name,
        to_mcp_root: { name: name }
      )
    end
    
    it 'registers a root' do
      manager.register(root)
      
      expect(manager.instance_variable_get(:@roots)).to have_key(name)
      expect(manager.instance_variable_get(:@roots)[name]).to eq(root)
    end
    
    it 'logs the registration' do
      expect(logger).to receive(:debug).with("Registered root: #{name}")
      manager.register(root)
    end
    
    it 'allows registering with a custom key' do
      custom_key = 'custom_key'
      manager.register(root, custom_key)
      
      expect(manager.instance_variable_get(:@roots)).to have_key(custom_key)
      expect(manager.instance_variable_get(:@roots)[custom_key]).to eq(root)
    end
    
    it 'raises a RootError if a root with the same key already exists' do
      manager.register(root)
      
      expect {
        manager.register(root)
      }.to raise_error(MCP::Errors::RootError, "Root with key '#{name}' already exists")
    end
  end
  
  describe '#unregister' do
    let(:name) { 'test_root' }
    let(:root) { instance_double(root_class, name: name) }
    
    before do
      manager.instance_variable_get(:@roots)[name] = root
    end
    
    it 'unregisters a root' do
      result = manager.unregister(name)
      
      expect(result).to eq(root)
      expect(manager.instance_variable_get(:@roots)).not_to have_key(name)
    end
    
    it 'logs the unregistration' do
      expect(logger).to receive(:debug).with("Unregistered root: #{name}")
      manager.unregister(name)
    end
    
    it 'returns nil if the root does not exist' do
      result = manager.unregister('nonexistent')
      
      expect(result).to be_nil
      expect(logger).not_to have_received(:debug)
    end
  end
  
  describe '#get' do
    let(:name) { 'test_root' }
    let(:root) { instance_double(root_class, name: name) }
    
    before do
      manager.instance_variable_get(:@roots)[name] = root
    end
    
    it 'returns the root with the given key' do
      result = manager.get(name)
      
      expect(result).to eq(root)
    end
    
    it 'returns nil if the root does not exist' do
      result = manager.get('nonexistent')
      
      expect(result).to be_nil
    end
  end
  
  describe '#exists?' do
    let(:name) { 'test_root' }
    
    before do
      manager.instance_variable_get(:@roots)[name] = 'dummy_root'
    end
    
    it 'returns true if the root exists' do
      expect(manager.exists?(name)).to be(true)
    end
    
    it 'returns false if the root does not exist' do
      expect(manager.exists?('nonexistent')).to be(false)
    end
  end
  
  describe '#all' do
    let(:roots) do
      {
        'root1' => 'dummy_root1',
        'root2' => 'dummy_root2'
      }
    end
    
    before do
      manager.instance_variable_set(:@roots, roots)
    end
    
    it 'returns all registered roots' do
      result = manager.all
      
      expect(result).to eq(roots)
    end
  end
  
  describe '#list' do
    let(:name) { 'test_root' }
    let(:root) { instance_double(root_class, name: name) }
    let(:list_result) { [{ name: 'file.txt', path: '/file.txt', type: 'file' }] }
    
    before do
      allow(root).to receive(:list).and_return(list_result)
      manager.instance_variable_get(:@roots)[name] = root
    end
    
    it 'calls list on the root and returns the result' do
      result = manager.list(name)
      
      expect(root).to have_received(:list).with('')
      expect(result).to eq(list_result)
    end
    
    it 'passes the path to the root' do
      path = 'subdir'
      manager.list(name, path)
      
      expect(root).to have_received(:list).with(path)
    end
    
    it 'raises RootError if the root does not exist' do
      expect {
        manager.list('nonexistent')
      }.to raise_error(MCP::Errors::RootError, "Root not found: nonexistent")
    end
    
    it 'handles errors from the root' do
      allow(root).to receive(:list).and_raise(StandardError.new("List error"))
      
      expect(logger).to receive(:error).with("Error listing root '#{name}': List error")
      
      expect {
        manager.list(name)
      }.to raise_error(MCP::Errors::RootError, "Error listing root '#{name}': List error")
    end
  end
  
  describe '#read' do
    let(:name) { 'test_root' }
    let(:path) { 'file.txt' }
    let(:root) { instance_double(root_class, name: name) }
    let(:content) { "File content" }
    
    before do
      allow(root).to receive(:read).and_return(content)
      manager.instance_variable_get(:@roots)[name] = root
    end
    
    it 'calls read on the root and returns the result' do
      result = manager.read(name, path)
      
      expect(root).to have_received(:read).with(path)
      expect(result).to eq(content)
    end
    
    it 'raises RootError if the root does not exist' do
      expect {
        manager.read('nonexistent', path)
      }.to raise_error(MCP::Errors::RootError, "Root not found: nonexistent")
    end
    
    it 'handles errors from the root' do
      allow(root).to receive(:read).and_raise(StandardError.new("Read error"))
      
      expect(logger).to receive(:error).with("Error reading from root '#{name}': Read error")
      
      expect {
        manager.read(name, path)
      }.to raise_error(MCP::Errors::RootError, "Error reading from root '#{name}': Read error")
    end
  end
  
  describe '#write' do
    let(:name) { 'test_root' }
    let(:path) { 'file.txt' }
    let(:content) { "New content" }
    let(:root) { instance_double(root_class, name: name) }
    
    before do
      allow(root).to receive(:write).and_return(true)
      manager.instance_variable_get(:@roots)[name] = root
    end
    
    it 'calls write on the root and returns the result' do
      result = manager.write(name, path, content)
      
      expect(root).to have_received(:write).with(path, content)
      expect(result).to eq(true)
    end
    
    it 'raises RootError if the root does not exist' do
      expect {
        manager.write('nonexistent', path, content)
      }.to raise_error(MCP::Errors::RootError, "Root not found: nonexistent")
    end
    
    it 'handles errors from the root' do
      allow(root).to receive(:write).and_raise(StandardError.new("Write error"))
      
      expect(logger).to receive(:error).with("Error writing to root '#{name}': Write error")
      
      expect {
        manager.write(name, path, content)
      }.to raise_error(MCP::Errors::RootError, "Error writing to root '#{name}': Write error")
    end
  end
  
  describe '#create_root' do
    it 'creates a new root with the given parameters' do
      expect(root_class).to receive(:new).with(
        'name',
        temp_dir,
        description: 'desc',
        allow_writes: true
      )
      
      manager.create_root('name', temp_dir, description: 'desc', allow_writes: true)
    end
  end
  
  describe '#register_handlers' do
    let(:server) { double('Server') }
    
    it 'registers method handlers on the server' do
      expect(server).to receive(:on_method).with('roots/list')
      expect(server).to receive(:on_method).with('roots/read')
      expect(server).to receive(:on_method).with('roots/write')
      
      manager.register_handlers(server)
    end
  end
  
  describe '#handle_list' do
    let(:root1) { instance_double(root_class, to_mcp_root: { name: 'root1' }) }
    let(:root2) { instance_double(root_class, to_mcp_root: { name: 'root2' }) }
    
    before do
      roots = {
        'root1' => root1,
        'root2' => root2
      }
      manager.instance_variable_set(:@roots, roots)
    end
    
    it 'returns a hash with all roots' do
      result = manager.send(:handle_list)
      
      expect(result).to be_a(Hash)
      expect(result[:roots]).to be_an(Array)
      expect(result[:roots]).to contain_exactly({ name: 'root1' }, { name: 'root2' })
    end
  end
  
  describe '#handle_read' do
    let(:root_name) { 'test_root' }
    let(:path) { 'file.txt' }
    let(:content) { "File content" }
    
    before do
      allow(manager).to receive(:read).and_return(content)
    end
    
    it 'reads the file from the specified root' do
      params = { root: root_name, path: path }
      
      result = manager.send(:handle_read, params)
      
      expect(manager).to have_received(:read).with(root_name, path)
      expect(result).to be_a(Hash)
      expect(result[:contents]).to be_an(Array)
      expect(result[:contents].first[:content]).to eq(content)
      expect(result[:contents].first[:mime_type]).to eq('text/plain')
    end
    
    it 'uses an empty path if not provided' do
      params = { root: root_name }
      
      manager.send(:handle_read, params)
      
      expect(manager).to have_received(:read).with(root_name, '')
    end
    
    it 'determines MIME type based on file extension' do
      file_types = {
        'file.txt' => 'text/plain',
        'file.html' => 'text/html',
        'file.json' => 'application/json',
        'file.md' => 'text/markdown',
        'file.csv' => 'text/csv',
        'file.bin' => 'application/octet-stream'
      }
      
      file_types.each do |file, mime_type|
        params = { root: root_name, path: file }
        result = manager.send(:handle_read, params)
        expect(result[:contents].first[:mime_type]).to eq(mime_type)
      end
    end
    
    it 're-raises RootError' do
      allow(manager).to receive(:read).and_raise(MCP::Errors::RootError.new("Root not found"))
      
      expect {
        manager.send(:handle_read, { root: 'nonexistent' })
      }.to raise_error(MCP::Errors::RootError, "Root not found")
    end
    
    it 'wraps other errors' do
      error_message = "Something went wrong"
      allow(manager).to receive(:read).and_raise(StandardError.new(error_message))
      
      expect(logger).to receive(:error).with("Error reading root #{root_name}: #{error_message}")
      
      expect {
        manager.send(:handle_read, { root: root_name })
      }.to raise_error(MCP::Errors::RootError, "Error reading root: #{error_message}")
    end
  end
  
  describe '#handle_write' do
    let(:root_name) { 'test_root' }
    let(:path) { 'file.txt' }
    let(:content) { "New content" }
    
    before do
      allow(manager).to receive(:write).and_return(true)
    end
    
    it 'writes to the specified file' do
      params = { root: root_name, path: path, content: content }
      
      result = manager.send(:handle_write, params)
      
      expect(manager).to have_received(:write).with(root_name, path, content)
      expect(result).to eq({ success: true })
    end
    
    it 'returns success: false if write returns false' do
      allow(manager).to receive(:write).and_return(false)
      
      params = { root: root_name, path: path, content: content }
      result = manager.send(:handle_write, params)
      
      expect(result).to eq({ success: false })
    end
    
    it 're-raises RootError' do
      allow(manager).to receive(:write).and_raise(MCP::Errors::RootError.new("Root not found"))
      
      expect {
        manager.send(:handle_write, { root: 'nonexistent', path: path, content: content })
      }.to raise_error(MCP::Errors::RootError, "Root not found")
    end
    
    it 'wraps other errors' do
      error_message = "Something went wrong"
      allow(manager).to receive(:write).and_raise(StandardError.new(error_message))
      
      expect(logger).to receive(:error).with("Error writing to root #{root_name}: #{error_message}")
      
      expect {
        manager.send(:handle_write, { root: root_name, path: path, content: content })
      }.to raise_error(MCP::Errors::RootError, "Error writing to root: #{error_message}")
    end
  end
end