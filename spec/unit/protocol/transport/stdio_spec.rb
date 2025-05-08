# frozen_string_literal: true

RSpec.describe MCP::Protocol::Transport::STDIO do
  let(:stdin) { StringIO.new }
  let(:stdout) { StringIO.new }
  let(:transport) { described_class.new(stdin: stdin, stdout: stdout) }
  
  describe '#initialize' do
    it 'uses provided stdin and stdout' do
      expect(transport.instance_variable_get(:@stdin)).to eq(stdin)
      expect(transport.instance_variable_get(:@stdout)).to eq(stdout)
    end
    
    it 'uses STDIN and STDOUT if not provided' do
      # We can't test with the actual STDIN/STDOUT, so we need to stub them
      stub_const('STDIN', double)
      stub_const('STDOUT', double)
      
      transport = described_class.new
      expect(transport.instance_variable_get(:@stdin)).to eq(STDIN)
      expect(transport.instance_variable_get(:@stdout)).to eq(STDOUT)
    end
    
    it 'creates an empty handlers hash' do
      expect(transport.instance_variable_get(:@handlers)).to eq({})
    end
  end
  
  describe '#connect' do
    it 'creates and starts the reader thread' do
      thread = double
      allow(Thread).to receive(:new).and_return(thread)
      
      expect(Thread).to receive(:new)
      transport.connect
      
      expect(transport.instance_variable_get(:@reader_thread)).to eq(thread)
    end
    
    it 'returns a connection' do
      # Stub Thread.new to avoid actually creating a thread
      allow(Thread).to receive(:new).and_return(double)
      
      connection = transport.connect
      expect(connection).to be_a(MCP::Protocol::Connection)
    end
  end
  
  describe '#disconnect' do
    it 'kills the reader thread if it exists' do
      thread = double(kill: nil)
      allow(transport).to receive(:reader_thread).and_return(thread)
      
      expect(thread).to receive(:kill)
      transport.disconnect
    end
    
    it 'does nothing if no reader thread exists' do
      allow(transport).to receive(:reader_thread).and_return(nil)
      
      expect {
        transport.disconnect
      }.not_to raise_error
    end
  end
  
  describe '#connected?' do
    it 'returns true if reader thread exists and is alive' do
      thread = double(alive?: true)
      allow(transport).to receive(:reader_thread).and_return(thread)
      
      expect(transport.connected?).to be(true)
    end
    
    it 'returns false if reader thread does not exist' do
      allow(transport).to receive(:reader_thread).and_return(nil)
      expect(transport.connected?).to be(false)
    end
    
    it 'returns false if reader thread is not alive' do
      thread = double(alive?: false)
      allow(transport).to receive(:reader_thread).and_return(thread)
      
      expect(transport.connected?).to be(false)
    end
  end
  
  describe '#send_message' do
    let(:message) { { jsonrpc: '2.0', method: 'test', id: '123' } }
    
    it 'writes the message as JSON to stdout' do
      expect(stdout).to receive(:puts).with(JSON.generate(message))
      expect(stdout).to receive(:flush)
      
      transport.send_message(message)
    end
    
    it 'stores a handler for requests with ID' do
      transport.send_message(message)
      
      handlers = transport.instance_variable_get(:@handlers)
      expect(handlers).to have_key('123')
    end
    
    it 'does not store a handler for notifications without ID' do
      notification = { jsonrpc: '2.0', method: 'test' }
      transport.send_message(notification)
      
      handlers = transport.instance_variable_get(:@handlers)
      expect(handlers).to be_empty
    end
  end
  
  describe '#on_event' do
    it 'registers an event handler' do
      handler = Proc.new {}
      transport.on_event('test_event', &handler)
      
      handlers = transport.instance_variable_get(:@event_handlers)
      expect(handlers['test_event']).to eq(handler)
    end
  end
  
  describe 'reader thread' do
    it 'reads and processes messages from stdin' do
      # Create a custom StringIO to simulate stdin
      input = StringIO.new
      transport = described_class.new(stdin: input, stdout: stdout)
      
      # Set up a message handler
      handler = double
      transport.instance_variable_set(:@handlers, { '123' => handler })
      
      # Set up event handlers
      event_handler = double
      transport.instance_variable_set(:@event_handlers, { 'test_event' => event_handler })
      
      # Prepare messages in the input
      request_response = { jsonrpc: '2.0', result: 'test result', id: '123' }
      notification = { jsonrpc: '2.0', method: 'test_event', params: { data: 'test' } }
      
      input.string = [
        JSON.generate(request_response),
        JSON.generate(notification)
      ].join("\n")
      
      # Reset position to beginning
      input.rewind
      
      # Mock the handler to check it receives the correct result
      expect(handler).to receive(:call).with(request_response)
      
      # Mock the event handler to check it receives the correct params
      expect(event_handler).to receive(:call).with({ data: 'test' })
      
      # Manually run the reader method (normally run in a thread)
      # We need to break after processing our prepared messages
      count = 0
      allow(input).to receive(:gets) do
        count += 1
        if count <= 2
          input.gets
        else
          nil
        end
      end
      
      transport.send(:reader_loop)
    end
  end
end