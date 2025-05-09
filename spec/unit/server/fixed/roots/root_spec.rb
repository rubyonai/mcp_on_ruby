# frozen_string_literal: true

RSpec.describe "MCP::Server::Roots::Root" do
  let(:root_class) { MCP::Server::Roots::Root }
  let(:name) { 'test_root' }
  let(:temp_dir) { Dir.mktmpdir }
  let(:root) { root_class.new(name, temp_dir) }
  
  after do
    FileUtils.remove_entry(temp_dir)
  end
  
  describe '#initialize' do
    it 'sets name, path, description, and allow_writes' do
      expect(root.name).to eq(name)
      expect(root.path).to eq(temp_dir)
      expect(root.description).to eq("")
      expect(root.allow_writes).to eq(false)
    end
    
    it 'accepts custom description and allow_writes' do
      custom_root = root_class.new(name, temp_dir, description: "Custom description", allow_writes: true)
      expect(custom_root.description).to eq("Custom description")
      expect(custom_root.allow_writes).to eq(true)
    end
    
    it 'expands the path' do
      relative_root = root_class.new(name, '.')
      expect(relative_root.path).to eq(File.expand_path('.'))
    end
  end
  
  describe '#to_mcp_root' do
    it 'returns a hash with root information' do
      result = root.to_mcp_root
      
      expect(result).to be_a(Hash)
      expect(result[:name]).to eq(name)
      expect(result[:description]).to eq("")
      expect(result[:allowWrites]).to eq(false)
    end
    
    it 'includes custom values when provided' do
      custom_root = root_class.new(name, temp_dir, description: "Custom description", allow_writes: true)
      result = custom_root.to_mcp_root
      
      expect(result[:description]).to eq("Custom description")
      expect(result[:allowWrites]).to eq(true)
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
    
    it 'lists files and directories in the root path' do
      entries = root.list
      
      expect(entries).to be_an(Array)
      expect(entries.length).to eq(4)
      
      file_entries = entries.select { |e| e[:type] == 'file' }
      dir_entries = entries.select { |e| e[:type] == 'directory' }
      
      expect(file_entries.length).to eq(2)
      expect(dir_entries.length).to eq(2)
      
      paths = entries.map { |e| e[:path] }
      expect(paths.any? { |p| p.end_with?('file1.txt') }).to be true
      expect(paths.any? { |p| p.end_with?('file2.txt') }).to be true
      expect(paths.any? { |p| p.end_with?('dir1') }).to be true
      expect(paths.any? { |p| p.end_with?('dir2') }).to be true
    end
    
    it 'lists files in a subdirectory' do
      entries = root.list('dir1')
      
      expect(entries).to be_an(Array)
      expect(entries.length).to eq(1)
      expect(entries.first[:path]).to include('nested.txt')
    end
  end
  
  describe '#read' do
    before do
      # Create test file with content
      @test_file = File.join(temp_dir, 'test.txt')
      File.write(@test_file, "Line 1\nLine 2\nLine 3\n")
    end
    
    it 'reads the entire file' do
      content = root.read('test.txt')
      expect(content).to eq("Line 1\nLine 2\nLine 3\n")
    end
  end
  
  describe '#write' do
    context 'with write access disabled' do
      it 'raises RootError' do
        expect {
          root.write('new.txt', 'content')
        }.to raise_error(MCP::Errors::RootError)
      end
    end
    
    context 'with write access enabled' do
      let(:writable_root) { root_class.new(name, temp_dir, allow_writes: true) }
      
      it 'writes content to a new file' do
        writable_root.write('new.txt', 'Hello, world!')
        
        file_path = File.join(temp_dir, 'new.txt')
        expect(File.exist?(file_path)).to be(true)
        expect(File.read(file_path)).to eq('Hello, world!')
      end
      
      it 'creates directories if needed' do
        writable_root.write('new_dir/new.txt', 'content')
        
        dir_path = File.join(temp_dir, 'new_dir')
        file_path = File.join(dir_path, 'new.txt')
        
        expect(Dir.exist?(dir_path)).to be(true)
        expect(File.exist?(file_path)).to be(true)
        expect(File.read(file_path)).to eq('content')
      end
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
    
    it 'returns the base path if path is empty' do
      resolved = root.send(:resolve_path, '')
      expect(resolved).to eq(temp_dir)
    end
    
    it 'raises RootError for paths outside the root' do
      expect {
        root.send(:resolve_path, '../outside')
      }.to raise_error(MCP::Errors::RootError)
    end
  end
end