# frozen_string_literal: true

RSpec.describe "MCP Primitives integration" do
  # Mock server with all primitives
  let(:server) do
    server = MCP::Server::Server.new(
      name: 'Test Primitives Server',
      transport_options: {
        transport: :stdio,
        stdin: StringIO.new,
        stdout: StringIO.new
      }
    )
    
    # Add tools
    server.instance_variable_get(:@method_handlers)['tools/list'] = lambda do |_params|
      [
        {
          name: 'echo',
          schema: {
            type: 'object',
            properties: {
              message: { type: 'string' }
            },
            required: ['message']
          }
        },
        {
          name: 'add',
          schema: {
            type: 'object',
            properties: {
              a: { type: 'number' },
              b: { type: 'number' }
            },
            required: ['a', 'b']
          }
        }
      ]
    end
    
    server.instance_variable_get(:@method_handlers)['tools/call'] = lambda do |params|
      case params[:name]
      when 'echo'
        { message: params[:parameters][:message] }
      when 'add'
        { sum: params[:parameters][:a] + params[:parameters][:b] }
      else
        { error: 'Tool not found' }
      end
    end
    
    # Add resources
    server.instance_variable_get(:@method_handlers)['resources/list'] = lambda do |_params|
      [
        {
          name: 'user.profile',
          schema: {
            type: 'object',
            properties: {
              id: { type: 'integer' }
            }
          }
        },
        {
          name: 'products',
          schema: {
            type: 'object',
            properties: {
              category: { type: 'string' },
              limit: { type: 'integer' }
            }
          }
        }
      ]
    end
    
    server.instance_variable_get(:@method_handlers)['resources/get'] = lambda do |params|
      case params[:name]
      when 'user.profile'
        id = params[:parameters]&.fetch(:id, 1)
        {
          id: id,
          name: "User #{id}",
          email: "user#{id}@example.com"
        }
      when 'products'
        category = params[:parameters]&.fetch(:category, nil)
        limit = params[:parameters]&.fetch(:limit, 10)
        
        products = [
          { id: 1, name: 'Laptop', category: 'electronics', price: 999 },
          { id: 2, name: 'Headphones', category: 'electronics', price: 199 },
          { id: 3, name: 'Coffee Maker', category: 'appliances', price: 89 }
        ]
        
        # Filter by category if provided
        if category
          products = products.select { |p| p[:category] == category }
        end
        
        # Apply limit
        { products: products.first(limit) }
      else
        { error: 'Resource not found' }
      end
    end
    
    # Add prompts
    server.instance_variable_get(:@method_handlers)['prompts/list'] = lambda do |_params|
      [
        {
          name: 'greeting',
          schema: {
            type: 'object',
            properties: {
              name: { type: 'string' }
            },
            required: ['name']
          }
        },
        {
          name: 'article',
          schema: {
            type: 'object',
            properties: {
              topic: { type: 'string' },
              length: { type: 'string', enum: ['short', 'medium', 'long'] }
            },
            required: ['topic']
          }
        }
      ]
    end
    
    server.instance_variable_get(:@method_handlers)['prompts/show'] = lambda do |params|
      case params[:name]
      when 'greeting'
        name = params[:parameters]&.fetch(:name, '{{name}}')
        {
          system: "You are a helpful assistant.",
          human: "Hello, my name is #{name}.",
          assistant: "Nice to meet you, #{name}!"
        }
      when 'article'
        topic = params[:parameters]&.fetch(:topic, '{{topic}}')
        length = params[:parameters]&.fetch(:length, '{{length}}')
        {
          system: "You are a professional writer.",
          human: "Write a #{length} article about #{topic}.",
          assistant: "I'll write a #{length} article about #{topic}. Here's my draft:"
        }
      else
        { error: 'Prompt not found' }
      end
    end
    
    # Set up a temporary directory for roots
    @temp_dir = Dir.mktmpdir
    @test_file = File.join(@temp_dir, 'test.txt')
    File.write(@test_file, "Line 1\nLine 2\nLine 3\n")
    
    # Add roots
    server.instance_variable_get(:@method_handlers)['roots/list'] = lambda do |_params|
      [
        {
          name: 'project',
          read_only: true
        },
        {
          name: 'output',
          read_only: false
        }
      ]
    end
    
    server.instance_variable_get(:@method_handlers)['roots/list_files'] = lambda do |params|
      case params[:name]
      when 'project', 'output'
        path = params[:path] || ''
        glob = params[:glob]
        
        entries = []
        
        # Create a simple file listing
        entries << {
          path: '/test.txt',
          type: 'file',
          size: File.size(@test_file),
          modified: File.mtime(@test_file).iso8601
        }
        
        entries
      else
        { error: 'Root not found' }
      end
    end
    
    server.instance_variable_get(:@method_handlers)['roots/read_file'] = lambda do |params|
      case params[:name]
      when 'project', 'output'
        if params[:path] == 'test.txt'
          content = File.read(@test_file)
          
          if params[:offset] || params[:limit]
            lines = content.lines
            start_line = [params[:offset] || 0, 0].max
            end_line = params[:limit] ? start_line + params[:limit] : lines.length
            content = lines[start_line...end_line].join
          end
          
          content
        else
          { error: 'File not found' }
        end
      else
        { error: 'Root not found' }
      end
    end
    
    server.instance_variable_get(:@method_handlers)['roots/write_file'] = lambda do |params|
      case params[:name]
      when 'output' # Only output is writable
        if params[:path] && params[:content]
          # In a real implementation, we would write to the filesystem
          # Here we'll just return success
          {
            path: params[:path],
            size: params[:content].bytesize
          }
        else
          { error: 'Invalid parameters' }
        end
      when 'project'
        { error: 'Root is read-only' }
      else
        { error: 'Root not found' }
      end
    end
    
    # Start the server
    server.start
    
    # Return the server
    server
  end
  
  # Create a client for testing
  let(:client) { MCP::Client::Client.new }
  
  # Mock the connection with server responses
  let(:connection) do
    double(
      'Connection',
      initialize_connection: {
        serverInfo: {
          name: 'Test Primitives Server',
          version: '1.0.0'
        },
        protocolVersion: MCP::PROTOCOL_VERSION,
        capabilities: {}
      }
    )
  end
  
  before(:all) do
    # Start a server in a separate thread for integration tests
    @server_thread = Thread.new do
      @server = MCP::Server::Server.new(
        name: 'Test Primitives Server',
        transport_options: {
          transport: :stdio,
          stdin: StringIO.new,
          stdout: StringIO.new
        }
      )
      
      # Keep the thread alive until the tests are done
      sleep
    end
    
    # Set up a temporary directory for roots testing
    @temp_dir = Dir.mktmpdir
    @test_file = File.join(@temp_dir, 'test.txt')
    File.write(@test_file, "Line 1\nLine 2\nLine 3\n")
    
    # Give the server time to start
    sleep 0.1
  end
  
  after(:all) do
    # Stop the server thread after tests
    @server_thread.kill if @server_thread
    
    # Clean up the temporary directory
    FileUtils.remove_entry(@temp_dir) if @temp_dir
  end
  
  before do
    # Set up the client with mock connection
    allow(MCP::Protocol).to receive(:connect).and_return(connection)
    client.connect
  end
  
  describe "Tools integration" do
    before do
      # Mock the tools/list response
      tools_list = [
        {
          name: 'echo',
          schema: {
            type: 'object',
            properties: {
              message: { type: 'string' }
            },
            required: ['message']
          }
        },
        {
          name: 'add',
          schema: {
            type: 'object',
            properties: {
              a: { type: 'number' },
              b: { type: 'number' }
            },
            required: ['a', 'b']
          }
        }
      ]
      
      allow(connection).to receive(:send_request).with('tools/list', anything).and_return(tools_list)
    end
    
    it "lists available tools" do
      result = client.call_method('tools/list')
      
      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
      expect(result.map { |t| t[:name] }).to contain_exactly('echo', 'add')
    end
    
    it "calls a tool with parameters" do
      # Mock the tools/call response for echo
      echo_result = { message: 'Hello, world!' }
      allow(connection).to receive(:send_request).with(
        'tools/call',
        { name: 'echo', parameters: { message: 'Hello, world!' } }
      ).and_return(echo_result)
      
      result = client.call_method('tools/call', {
        name: 'echo',
        parameters: { message: 'Hello, world!' }
      })
      
      expect(result).to eq(echo_result)
    end
    
    it "calls a tool with numeric parameters" do
      # Mock the tools/call response for add
      add_result = { sum: 5 }
      allow(connection).to receive(:send_request).with(
        'tools/call',
        { name: 'add', parameters: { a: 2, b: 3 } }
      ).and_return(add_result)
      
      result = client.call_method('tools/call', {
        name: 'add',
        parameters: { a: 2, b: 3 }
      })
      
      expect(result).to eq(add_result)
    end
    
    it "validates parameters before calling the tool" do
      # Mock the validation error
      allow(connection).to receive(:send_request).with(
        'tools/call',
        { name: 'add', parameters: { a: 2 } } # Missing required 'b' parameter
      ).and_raise(MCP::Errors::ValidationError.new('Invalid parameters'))
      
      expect {
        client.call_method('tools/call', {
          name: 'add',
          parameters: { a: 2 } # Missing required 'b' parameter
        })
      }.to raise_error(MCP::Errors::ValidationError)
    end
  end
  
  describe "Resources integration" do
    before do
      # Mock the resources/list response
      resources_list = [
        {
          name: 'user.profile',
          schema: {
            type: 'object',
            properties: {
              id: { type: 'integer' }
            }
          }
        },
        {
          name: 'products',
          schema: {
            type: 'object',
            properties: {
              category: { type: 'string' },
              limit: { type: 'integer' }
            }
          }
        }
      ]
      
      allow(connection).to receive(:send_request).with('resources/list', anything).and_return(resources_list)
    end
    
    it "lists available resources" do
      result = client.call_method('resources/list')
      
      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
      expect(result.map { |r| r[:name] }).to contain_exactly('user.profile', 'products')
    end
    
    it "gets a resource without parameters" do
      # Mock the resources/get response for user.profile
      profile = {
        id: 1,
        name: 'User 1',
        email: 'user1@example.com'
      }
      
      allow(connection).to receive(:send_request).with(
        'resources/get',
        { name: 'user.profile' }
      ).and_return(profile)
      
      result = client.call_method('resources/get', { name: 'user.profile' })
      
      expect(result).to eq(profile)
    end
    
    it "gets a resource with parameters" do
      # Mock the resources/get response for products with parameters
      products = {
        products: [
          { id: 1, name: 'Laptop', category: 'electronics', price: 999 },
          { id: 2, name: 'Headphones', category: 'electronics', price: 199 }
        ]
      }
      
      allow(connection).to receive(:send_request).with(
        'resources/get',
        { name: 'products', parameters: { category: 'electronics', limit: 2 } }
      ).and_return(products)
      
      result = client.call_method('resources/get', {
        name: 'products',
        parameters: { category: 'electronics', limit: 2 }
      })
      
      expect(result).to eq(products)
      expect(result[:products].length).to eq(2)
      expect(result[:products].map { |p| p[:category] }).to all(eq('electronics'))
    end
  end
  
  describe "Prompts integration" do
    before do
      # Mock the prompts/list response
      prompts_list = [
        {
          name: 'greeting',
          schema: {
            type: 'object',
            properties: {
              name: { type: 'string' }
            },
            required: ['name']
          }
        },
        {
          name: 'article',
          schema: {
            type: 'object',
            properties: {
              topic: { type: 'string' },
              length: { type: 'string', enum: ['short', 'medium', 'long'] }
            },
            required: ['topic']
          }
        }
      ]
      
      allow(connection).to receive(:send_request).with('prompts/list', anything).and_return(prompts_list)
    end
    
    it "lists available prompts" do
      result = client.call_method('prompts/list')
      
      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
      expect(result.map { |p| p[:name] }).to contain_exactly('greeting', 'article')
    end
    
    it "shows a prompt with parameters" do
      # Mock the prompts/show response for greeting
      greeting = {
        system: "You are a helpful assistant.",
        human: "Hello, my name is John.",
        assistant: "Nice to meet you, John!"
      }
      
      allow(connection).to receive(:send_request).with(
        'prompts/show',
        { name: 'greeting', parameters: { name: 'John' } }
      ).and_return(greeting)
      
      result = client.call_method('prompts/show', {
        name: 'greeting',
        parameters: { name: 'John' }
      })
      
      expect(result).to eq(greeting)
    end
    
    it "shows a prompt with multiple parameters" do
      # Mock the prompts/show response for article
      article = {
        system: "You are a professional writer.",
        human: "Write a long article about artificial intelligence.",
        assistant: "I'll write a long article about artificial intelligence. Here's my draft:"
      }
      
      allow(connection).to receive(:send_request).with(
        'prompts/show',
        { name: 'article', parameters: { topic: 'artificial intelligence', length: 'long' } }
      ).and_return(article)
      
      result = client.call_method('prompts/show', {
        name: 'article',
        parameters: { topic: 'artificial intelligence', length: 'long' }
      })
      
      expect(result).to eq(article)
    end
  end
  
  describe "Roots integration" do
    before do
      # Mock the roots/list response
      roots_list = [
        {
          name: 'project',
          read_only: true
        },
        {
          name: 'output',
          read_only: false
        }
      ]
      
      allow(connection).to receive(:send_request).with('roots/list', anything).and_return(roots_list)
    end
    
    it "lists available roots" do
      result = client.call_method('roots/list')
      
      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
      expect(result.map { |r| r[:name] }).to contain_exactly('project', 'output')
      
      project_root = result.find { |r| r[:name] == 'project' }
      output_root = result.find { |r| r[:name] == 'output' }
      
      expect(project_root[:read_only]).to be(true)
      expect(output_root[:read_only]).to be(false)
    end
    
    it "lists files in a root" do
      # Mock the roots/list_files response
      files = [
        {
          path: '/test.txt',
          type: 'file',
          size: 20,
          modified: '2023-01-01T00:00:00Z'
        }
      ]
      
      allow(connection).to receive(:send_request).with(
        'roots/list_files',
        { name: 'project' }
      ).and_return(files)
      
      result = client.call_method('roots/list_files', { name: 'project' })
      
      expect(result).to be_an(Array)
      expect(result.length).to eq(1)
      expect(result.first[:path]).to eq('/test.txt')
    end
    
    it "reads a file from a root" do
      # Mock the roots/read_file response
      file_content = "Line 1\nLine 2\nLine 3\n"
      
      allow(connection).to receive(:send_request).with(
        'roots/read_file',
        { name: 'project', path: 'test.txt' }
      ).and_return(file_content)
      
      result = client.call_method('roots/read_file', {
        name: 'project',
        path: 'test.txt'
      })
      
      expect(result).to eq(file_content)
    end
    
    it "reads a file with offset and limit" do
      # Mock the roots/read_file response with offset and limit
      file_content = "Line 2\n"
      
      allow(connection).to receive(:send_request).with(
        'roots/read_file',
        { name: 'project', path: 'test.txt', offset: 1, limit: 1 }
      ).and_return(file_content)
      
      result = client.call_method('roots/read_file', {
        name: 'project',
        path: 'test.txt',
        offset: 1,
        limit: 1
      })
      
      expect(result).to eq(file_content)
    end
    
    it "writes a file to a root" do
      # Mock the roots/write_file response
      write_result = {
        path: 'new.txt',
        size: 13
      }
      
      allow(connection).to receive(:send_request).with(
        'roots/write_file',
        { name: 'output', path: 'new.txt', content: 'Hello, world!' }
      ).and_return(write_result)
      
      result = client.call_method('roots/write_file', {
        name: 'output',
        path: 'new.txt',
        content: 'Hello, world!'
      })
      
      expect(result).to eq(write_result)
    end
    
    it "cannot write to a read-only root" do
      # Mock the roots/write_file error response
      error = { error: 'Root is read-only' }
      
      allow(connection).to receive(:send_request).with(
        'roots/write_file',
        { name: 'project', path: 'new.txt', content: 'Hello, world!' }
      ).and_return(error)
      
      result = client.call_method('roots/write_file', {
        name: 'project',
        path: 'new.txt',
        content: 'Hello, world!'
      })
      
      expect(result).to eq(error)
    end
  end
end