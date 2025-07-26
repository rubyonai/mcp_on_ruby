# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  add_filter '/vendor/'
  
  add_group 'Protocol', 'lib/mcp_on_ruby/protocol'
  add_group 'Server', 'lib/mcp_on_ruby/server'
  add_group 'Client', 'lib/mcp_on_ruby/client'
  add_group 'Auth', ['lib/mcp_on_ruby/server/auth', 'lib/mcp_on_ruby/client/auth']
end

require 'mcp_on_ruby'
require 'webmock/rspec'
require 'securerandom'
require 'json'
require 'tempfile'

# Initialize MCP configuration for tests
MCP.configure do |config|
  config.log_level = Logger::FATAL # Minimize test noise
  
  # Client transport options
  config.client_transport = :http
  config.client_url = 'http://localhost:3000/mcp'
  
  # Server transport options
  config.server_transport = :http
  config.server_port = 3000
  config.server_host = 'localhost'
end

# Load all support files
Dir[File.join(File.dirname(__FILE__), 'support', '**', '*.rb')].sort.each { |f| require f }

# Configure RSpec
RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  # Enable the focus tag for specific tests
  config.filter_run_when_matching :focus

  # Run tests in random order to surface order dependencies
  config.order = :random
  Kernel.srand config.seed

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Reset WebMock after each test
  config.after(:each) do
    WebMock.reset!
  end
  
  # Include test helpers
  config.include MCPTestHelpers
end

# Helper method to create a temporary directory
def create_temp_dir
  dir = Dir.mktmpdir
  
  yield(dir) if block_given?
  
  dir
ensure
  FileUtils.remove_entry(dir) if block_given? && dir
end

# Helper method to create a temporary file with content
def create_temp_file(content = "test content")
  file = Tempfile.new('test')
  file.write(content)
  file.close
  
  yield(file.path) if block_given?
  
  file.path
ensure
  file.unlink if block_given? && file
end

# Helper to create a mock for the MCP::Protocol::Transport class
class MockTransport
  attr_reader :messages, :connected
  
  def initialize
    @messages = []
    @connected = false
    @response_handlers = {}
  end
  
  def connect
    @connected = true
    self
  end
  
  def disconnect
    @connected = false
  end
  
  def connected?
    @connected
  end
  
  def send_message(message)
    @messages << message
    
    # Return a mock response for requests
    if message[:id]
      case message[:method]
      when 'initialize'
        {
          serverInfo: {
            name: 'Mock MCP Server',
            version: '1.0.0'
          },
          protocolVersion: MCP::PROTOCOL_VERSION,
          capabilities: {}
        }
      when 'tools/list'
        []
      when 'resources/list'
        []
      when 'prompts/list'
        []
      when 'roots/list'
        []
      else
        {}
      end
    end
  end
  
  def on_event(event_type, &block)
    @response_handlers[event_type] = block
  end
  
  def trigger_event(event_type, data)
    handler = @response_handlers[event_type]
    handler&.call(data)
  end
end

# Helper to create a mock for the MCP::Protocol::Connection class
class MockConnection
  attr_reader :transport, :initialized
  
  def initialize(transport)
    @transport = transport
    @initialized = false
  end
  
  def initialize_connection(options = {})
    @initialized = true
    
    {
      serverInfo: {
        name: 'Mock MCP Server',
        version: '1.0.0'
      },
      protocolVersion: MCP::PROTOCOL_VERSION,
      capabilities: {}
    }
  end
  
  def send_request(method, params = nil)
    @transport.send_message(MCP::Protocol::JsonRPC.request(method, params))
  end
  
  def send_notification(method, params = nil)
    @transport.send_message(MCP::Protocol::JsonRPC.notification(method, params))
  end
end