# frozen_string_literal: true

RSpec.describe MCP::Server::Roots::Root do
  let(:name) { 'test_root' }
  let(:temp_dir) { Dir.mktmpdir }
  let(:root) { described_class.new(name, temp_dir) }
  
  after do
    FileUtils.remove_entry(temp_dir)
  end
  
  describe '#initialize' do
    it 'sets name and path' do
      expect(root.name).to eq(name)
      expect(root.path).to eq(temp_dir)
    end
    
    it 'defaults to read-only mode' do
      expect(root.read_only?).to be(true)
    end
    
    it 'can be configured as writable' do
      writable_root = described_class.new(name, temp_dir, read_only: false)
      expect(writable_root.read_only?).to be(false)
    end
    
    it 'validates that the path exists' do
      expect {
        described_class.new(name, '/nonexistent/path')
      }.to raise_error(MCP::Errors::InvalidPathError)
    end
    
    it 'expands relative paths' do
      root = described_class.new(name, '.')
      expect(root.path).to eq(File.expand_path('.'))
    end
  end
  
  describe '#list' do
    before do
      # Create test directory structure
      FileUtils.mkdir_p(File.join(temp_dir, 'dir1'))
      FileUtils.mkdir_p(File.join(temp_dir, 'dir2'))
      FileUtils.touch(File.join(temp_dir, 'file1.txt'))
      FileUtils.touch(File.join(temp_dir, 'file2.txt'))
      FileUtils.touch(File.join(temp_dir, 'dir1', 'nested.txt'))
    end
    
    it 'lists all files and directories in the root path' do
      entries = root.list
      
      expect(entries).to be_an(Array)
      expect(entries.length).to eq(4)
      
      # Check for directories and files
      paths = entries.map { |e| e[:path] }
      expect(paths).to include('/dir1', '/dir2', '/file1.txt', '/file2.txt')
      
      # Verify entry types
      dir_entries = entries.select { |e| e[:type] == 'directory' }
      file_entries = entries.select { |e| e[:type] == 'file' }
      expect(dir_entries.length).to eq(2)
      expect(file_entries.length).to eq(2)
      
      # Verify entry has size and modified time
      file_entry = entries.find { |e| e[:path] == '/file1.txt' }
      expect(file_entry[:size]).to be_a(Integer)
      expect(file_entry[:modified]).to be_a(String)
    end
    
    it 'lists files in a subdirectory' do
      entries = root.list('dir1')
      
      expect(entries).to be_an(Array)
      expect(entries.length).to eq(1)
      expect(entries.first[:path]).to eq('/dir1/nested.txt')
    end
    
    it 'lists files matching a glob pattern' do
      entries = root.list(nil, '*.txt')
      
      expect(entries).to be_an(Array)
      expect(entries.length).to eq(2)
      paths = entries.map { |e| e[:path] }
      expect(paths).to contain_exactly('/file1.txt', '/file2.txt')
    end
    
    it 'lists files in a subdirectory matching a glob pattern' do
      entries = root.list('dir1', '*.txt')
      
      expect(entries).to be_an(Array)
      expect(entries.length).to eq(1)
      expect(entries.first[:path]).to eq('/dir1/nested.txt')
    end
    
    it 'raises InvalidPathError for paths outside the root' do
      expect {
        root.list('../')
      }.to raise_error(MCP::Errors::InvalidPathError)
    end
  end
  
  describe '#read_file' do
    before do
      # Create test file with content
      @test_file = File.join(temp_dir, 'test.txt')
      File.write(@test_file, "Line 1\nLine 2\nLine 3\nLine 4\nLine 5\n")
    end
    
    it 'reads the entire file' do
      content = root.read_file('test.txt')
      expect(content).to eq("Line 1\nLine 2\nLine 3\nLine 4\nLine 5\n")
    end
    
    it 'reads a file with offset and limit' do
      content = root.read_file('test.txt', 1, 2)
      expect(content).to eq("Line 2\nLine 3\n")
    end
    
    it 'raises FileNotFoundError for non-existent files' do
      expect {
        root.read_file('nonexistent.txt')
      }.to raise_error(MCP::Errors::FileNotFoundError)
    end
    
    it 'raises InvalidPathError for paths outside the root' do
      expect {
        root.read_file('../test.txt')
      }.to raise_error(MCP::Errors::InvalidPathError)
    end
  end
  
  describe '#write_file' do
    let(:writable_root) { described_class.new(name, temp_dir, read_only: false) }
    
    it 'raises ReadOnlyRootError for read-only roots' do
      expect {
        root.write_file('new.txt', 'content')
      }.to raise_error(MCP::Errors::ReadOnlyRootError)
    end
    
    it 'writes content to a new file' do
      writable_root.write_file('new.txt', 'Hello, world!')
      
      file_path = File.join(temp_dir, 'new.txt')
      expect(File.exist?(file_path)).to be(true)
      expect(File.read(file_path)).to eq('Hello, world!')
    end
    
    it 'overwrites existing files' do
      File.write(File.join(temp_dir, 'existing.txt'), 'old content')
      
      writable_root.write_file('existing.txt', 'new content')
      
      file_path = File.join(temp_dir, 'existing.txt')
      expect(File.read(file_path)).to eq('new content')
    end
    
    it 'creates directories if they do not exist' do
      writable_root.write_file('new_dir/new.txt', 'content')
      
      dir_path = File.join(temp_dir, 'new_dir')
      file_path = File.join(dir_path, 'new.txt')
      
      expect(Dir.exist?(dir_path)).to be(true)
      expect(File.exist?(file_path)).to be(true)
      expect(File.read(file_path)).to eq('content')
    end
    
    it 'returns information about the written file' do
      result = writable_root.write_file('new.txt', 'Hello, world!')
      
      expect(result).to include(:path, :size)
      expect(result[:path]).to eq('new.txt')
      expect(result[:size]).to eq(13) # Length of 'Hello, world!'
    end
    
    it 'raises InvalidPathError for paths outside the root' do
      expect {
        writable_root.write_file('../outside.txt', 'content')
      }.to raise_error(MCP::Errors::InvalidPathError)
    end
  end
  
  describe '#resolve_path' do
    it 'joins the base path with the given path' do
      resolved = root.send(:resolve_path, 'file.txt')
      expect(resolved).to eq(File.join(temp_dir, 'file.txt'))
    end
    
    it 'normalizes the path' do
      resolved = root.send(:resolve_path, 'dir/../file.txt')
      expect(resolved).to eq(File.join(temp_dir, 'file.txt'))
    end
    
    it 'returns the base path if no path is given' do
      resolved = root.send(:resolve_path, nil)
      expect(resolved).to eq(temp_dir)
    end
  end
  
  describe '#validate_path' do
    it 'raises InvalidPathError for paths outside the root' do
      outside_path = File.expand_path('../outside', temp_dir)
      
      expect {
        root.send(:validate_path, outside_path)
      }.to raise_error(MCP::Errors::InvalidPathError)
    end
    
    it 'returns true for valid paths' do
      inside_path = File.join(temp_dir, 'inside')
      
      expect(root.send(:validate_path, inside_path)).to be(true)
    end
  end
end