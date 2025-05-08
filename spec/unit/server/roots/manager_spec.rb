# frozen_string_literal: true

RSpec.describe MCP::Server::Roots::Manager do
  let(:manager) { described_class.new }
  let(:temp_dir) { Dir.mktmpdir }
  
  after do
    FileUtils.remove_entry(temp_dir)
  end
  
  describe '#initialize' do
    it 'creates an empty roots hash' do
      expect(manager.instance_variable_get(:@roots)).to eq({})
    end
  end
  
  describe '#register' do
    let(:name) { 'test_root' }
    
    it 'registers a root with the given name and path' do
      manager.register(name, temp_dir)
      
      roots = manager.instance_variable_get(:@roots)
      expect(roots).to have_key(name)
      expect(roots[name]).to be_a(MCP::Server::Roots::Root)
    end
    
    it 'passes options to the root' do
      manager.register(name, temp_dir, read_only: false)
      
      root = manager.instance_variable_get(:@roots)[name]
      expect(root.read_only?).to be(false)
    end
    
    it 'overwrites an existing root with the same name' do
      manager.register(name, temp_dir)
      
      new_dir = Dir.mktmpdir
      begin
        manager.register(name, new_dir)
        
        root = manager.instance_variable_get(:@roots)[name]
        expect(root.path).to eq(new_dir)
      ensure
        FileUtils.remove_entry(new_dir)
      end
    end
  end
  
  describe '#list' do
    before do
      manager.register('root1', temp_dir)
      
      second_dir = Dir.mktmpdir
      manager.register('root2', second_dir, read_only: false)
      
      # Need to store for cleanup
      @second_dir = second_dir
    end
    
    after do
      FileUtils.remove_entry(@second_dir)
    end
    
    it 'returns a list of all registered roots with their properties' do
      roots = manager.list
      
      expect(roots).to be_an(Array)
      expect(roots.length).to eq(2)
      expect(roots.map { |r| r[:name] }).to contain_exactly('root1', 'root2')
      
      # Check root properties
      root1 = roots.find { |r| r[:name] == 'root1' }
      root2 = roots.find { |r| r[:name] == 'root2' }
      
      expect(root1[:read_only]).to be(true)
      expect(root2[:read_only]).to be(false)
    end
    
    it 'returns an empty array when no roots are registered' do
      manager = described_class.new
      expect(manager.list).to eq([])
    end
  end
  
  describe '#list_files' do
    before do
      manager.register('test_root', temp_dir)
      
      # Create test directory structure
      FileUtils.mkdir_p(File.join(temp_dir, 'dir1'))
      FileUtils.touch(File.join(temp_dir, 'file1.txt'))
      FileUtils.touch(File.join(temp_dir, 'file2.txt'))
    end
    
    it 'lists files in the specified root' do
      entries = manager.list_files('test_root')
      
      expect(entries).to be_an(Array)
      expect(entries.length).to eq(3)
      
      paths = entries.map { |e| e[:path] }
      expect(paths).to include('/dir1', '/file1.txt', '/file2.txt')
    end
    
    it 'lists files in a subdirectory of the root' do
      entries = manager.list_files('test_root', 'dir1')
      
      expect(entries).to be_an(Array)
      expect(entries.length).to eq(0) # Empty directory
    end
    
    it 'lists files matching a glob pattern' do
      entries = manager.list_files('test_root', nil, '*.txt')
      
      expect(entries).to be_an(Array)
      expect(entries.length).to eq(2)
      
      paths = entries.map { |e| e[:path] }
      expect(paths).to contain_exactly('/file1.txt', '/file2.txt')
    end
    
    it 'raises RootNotFoundError if the root does not exist' do
      expect {
        manager.list_files('nonexistent')
      }.to raise_error(MCP::Errors::RootNotFoundError)
    end
  end
  
  describe '#read_file' do
    before do
      manager.register('test_root', temp_dir)
      
      # Create test file with content
      @test_file = File.join(temp_dir, 'test.txt')
      File.write(@test_file, "Line 1\nLine 2\nLine 3\n")
    end
    
    it 'reads a file from the specified root' do
      content = manager.read_file('test_root', 'test.txt')
      expect(content).to eq("Line 1\nLine 2\nLine 3\n")
    end
    
    it 'reads a file with offset and limit' do
      content = manager.read_file('test_root', 'test.txt', 1, 1)
      expect(content).to eq("Line 2\n")
    end
    
    it 'raises RootNotFoundError if the root does not exist' do
      expect {
        manager.read_file('nonexistent', 'test.txt')
      }.to raise_error(MCP::Errors::RootNotFoundError)
    end
    
    it 'raises FileNotFoundError if the file does not exist' do
      expect {
        manager.read_file('test_root', 'nonexistent.txt')
      }.to raise_error(MCP::Errors::FileNotFoundError)
    end
  end
  
  describe '#write_file' do
    before do
      manager.register('read_only', temp_dir)
      manager.register('writable', temp_dir, read_only: false)
    end
    
    it 'writes a file to the specified root' do
      manager.write_file('writable', 'new.txt', 'Hello, world!')
      
      file_path = File.join(temp_dir, 'new.txt')
      expect(File.exist?(file_path)).to be(true)
      expect(File.read(file_path)).to eq('Hello, world!')
    end
    
    it 'raises RootNotFoundError if the root does not exist' do
      expect {
        manager.write_file('nonexistent', 'new.txt', 'content')
      }.to raise_error(MCP::Errors::RootNotFoundError)
    end
    
    it 'raises ReadOnlyRootError if the root is read-only' do
      expect {
        manager.write_file('read_only', 'new.txt', 'content')
      }.to raise_error(MCP::Errors::ReadOnlyRootError)
    end
  end
  
  describe '#handle_list_method' do
    before do
      manager.register('root1', temp_dir)
      manager.register('root2', temp_dir, read_only: false)
    end
    
    it 'returns the list of roots' do
      result = manager.handle_list_method({})
      
      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
      expect(result.map { |r| r[:name] }).to contain_exactly('root1', 'root2')
    end
  end
  
  describe '#handle_list_files_method' do
    before do
      manager.register('test_root', temp_dir)
      
      # Create test file
      FileUtils.touch(File.join(temp_dir, 'file.txt'))
    end
    
    it 'lists files in the specified root' do
      params = { name: 'test_root' }
      result = manager.handle_list_files_method(params)
      
      expect(result).to be_an(Array)
      expect(result.length).to eq(1)
      expect(result.first[:path]).to eq('/file.txt')
    end
    
    it 'passes path and glob parameters' do
      params = {
        name: 'test_root',
        path: '.',
        glob: '*.txt'
      }
      
      result = manager.handle_list_files_method(params)
      
      expect(result).to be_an(Array)
      expect(result.length).to eq(1)
      expect(result.first[:path]).to eq('/file.txt')
    end
    
    it 'raises ValidationError if name parameter is missing' do
      expect {
        manager.handle_list_files_method({})
      }.to raise_error(MCP::Errors::ValidationError)
    end
    
    it 'raises RootNotFoundError if root does not exist' do
      expect {
        manager.handle_list_files_method({ name: 'nonexistent' })
      }.to raise_error(MCP::Errors::RootNotFoundError)
    end
  end
  
  describe '#handle_read_file_method' do
    before do
      manager.register('test_root', temp_dir)
      
      # Create test file with content
      @test_file = File.join(temp_dir, 'test.txt')
      File.write(@test_file, "Line 1\nLine 2\nLine 3\n")
    end
    
    it 'reads the specified file' do
      params = {
        name: 'test_root',
        path: 'test.txt'
      }
      
      result = manager.handle_read_file_method(params)
      expect(result).to eq("Line 1\nLine 2\nLine 3\n")
    end
    
    it 'passes offset and limit parameters' do
      params = {
        name: 'test_root',
        path: 'test.txt',
        offset: 1,
        limit: 1
      }
      
      result = manager.handle_read_file_method(params)
      expect(result).to eq("Line 2\n")
    end
    
    it 'raises ValidationError if name or path parameters are missing' do
      expect {
        manager.handle_read_file_method({ name: 'test_root' })
      }.to raise_error(MCP::Errors::ValidationError)
      
      expect {
        manager.handle_read_file_method({ path: 'test.txt' })
      }.to raise_error(MCP::Errors::ValidationError)
    end
    
    it 'raises RootNotFoundError if root does not exist' do
      expect {
        manager.handle_read_file_method({ name: 'nonexistent', path: 'test.txt' })
      }.to raise_error(MCP::Errors::RootNotFoundError)
    end
  end
  
  describe '#handle_write_file_method' do
    before do
      manager.register('writable', temp_dir, read_only: false)
    end
    
    it 'writes to the specified file' do
      params = {
        name: 'writable',
        path: 'new.txt',
        content: 'Hello, world!'
      }
      
      result = manager.handle_write_file_method(params)
      
      file_path = File.join(temp_dir, 'new.txt')
      expect(File.exist?(file_path)).to be(true)
      expect(File.read(file_path)).to eq('Hello, world!')
      
      expect(result).to include(:path, :size)
      expect(result[:path]).to eq('new.txt')
      expect(result[:size]).to eq(13)
    end
    
    it 'raises ValidationError if name, path, or content parameters are missing' do
      expect {
        manager.handle_write_file_method({ name: 'writable', path: 'new.txt' })
      }.to raise_error(MCP::Errors::ValidationError)
      
      expect {
        manager.handle_write_file_method({ name: 'writable', content: 'text' })
      }.to raise_error(MCP::Errors::ValidationError)
      
      expect {
        manager.handle_write_file_method({ path: 'new.txt', content: 'text' })
      }.to raise_error(MCP::Errors::ValidationError)
    end
    
    it 'raises RootNotFoundError if root does not exist' do
      expect {
        manager.handle_write_file_method({ name: 'nonexistent', path: 'new.txt', content: 'text' })
      }.to raise_error(MCP::Errors::RootNotFoundError)
    end
  end
end