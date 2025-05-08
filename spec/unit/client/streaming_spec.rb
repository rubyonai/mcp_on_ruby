# frozen_string_literal: true

RSpec.describe MCP::Client::Streaming do
  let(:client) { Object.new.extend(described_class) }
  let(:connection) { MockConnection.new(MockTransport.new) }
  
  before do
    client.instance_variable_set(:@logger, Logger.new(nil))
    client.instance_variable_set(:@connection, connection)
    client.instance_variable_set(:@connected, true)
    
    # Define validate_connection method (normally from Client class)
    def client.validate_connection
      raise MCP::Errors::ConnectionError, 'Not connected' unless @connected
    end
  end
  
  describe '#stream_call' do
    it 'validates connection before streaming' do
      client.instance_variable_set(:@connected, false)
      
      expect {
        client.stream_call('test/method', {}) {}
      }.to raise_error(MCP::Errors::ConnectionError)
    end
    
    it 'registers a stream event handler and sends the request' do
      request_id = nil
      
      expect(connection).to receive(:send_request) do |method, params|
        expect(method).to eq('test/method')
        expect(params).to eq({ param: 'value' })
        request_id = params[:id] if params.is_a?(Hash) # Capture request ID
        'response'
      end
      
      expect(connection).to receive(:on_event).with(/stream\/.*/)
      
      result = client.stream_call('test/method', { param: 'value' }) do |chunk|
        # Stream handler
      end
      
      expect(result).to eq('response')
    end
    
    it 'calls the block for each chunk of data' do
      chunks = []
      
      # Set up the mock transport to trigger events
      transport = MockTransport.new
      connection = MockConnection.new(transport)
      client.instance_variable_set(:@connection, connection)
      
      # Capture the event name for later triggering
      event_name = nil
      allow(connection).to receive(:on_event) do |name, &block|
        event_name = name
        transport.on_event(name, &block)
      end
      
      # Set up send_request to trigger stream events
      allow(connection).to receive(:send_request) do |method, params|
        # Simulate streaming chunks
        transport.trigger_event(event_name, { content: 'chunk 1' })
        transport.trigger_event(event_name, { content: 'chunk 2' })
        transport.trigger_event(event_name, { content: 'chunk 3' })
        'final response'
      end
      
      # Call stream_call and collect chunks
      result = client.stream_call('test/method', {}) do |chunk|
        chunks << chunk
      end
      
      # Verify chunks and final result
      expect(chunks).to eq([{ content: 'chunk 1' }, { content: 'chunk 2' }, { content: 'chunk 3' }])
      expect(result).to eq('final response')
    end
  end
  
  describe '#stream_resource' do
    it 'calls stream_call with the resources/stream method' do
      expect(client).to receive(:stream_call).with('resources/stream', {
        name: 'user.profile',
        parameters: { id: 123 }
      })
      
      client.stream_resource('user.profile', { id: 123 })
    end
    
    it 'passes the chunk handler to stream_call' do
      handler = Proc.new {}
      
      expect(client).to receive(:stream_call).with('resources/stream', {
        name: 'user.profile'
      }, &handler)
      
      client.stream_resource('user.profile', &handler)
    end
  end
  
  describe '#stream_completion' do
    it 'calls stream_call with the completion/stream method' do
      expect(client).to receive(:stream_call).with('completion/stream', {
        prompt: 'Hello',
        options: { temperature: 0.7 }
      })
      
      client.stream_completion('Hello', { temperature: 0.7 })
    end
    
    it 'passes the chunk handler to stream_call' do
      handler = Proc.new {}
      
      expect(client).to receive(:stream_call).with('completion/stream', {
        prompt: 'Hello'
      }, &handler)
      
      client.stream_completion('Hello', &handler)
    end
  end
end