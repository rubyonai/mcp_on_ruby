# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'MCP Client' do
  let(:options) do
    {
      name: 'Test Client',
      logger: Logger.new(nil)
    }
  end
  
  let(:client_class) { MCP::Client::Client }
  let(:client) { client_class.new(options) }
  let(:transport) { mock_transport }
  let(:connection) { mock_connection }
  
  before do
    allow(MCP::Protocol).to receive(:create_transport).and_return(transport)
    allow(transport).to receive(:connect).and_return(transport)
    allow(MCP::Protocol::Connection).to receive(:new).and_return(connection)
    
    # Stub server info 
    client.instance_variable_set(:@server_info, {
      name: 'Test Server',
      version: '1.0.0'
    })
  end
  
  describe 'initialization' do
    it 'sets client properties' do
      expect(client.name).to eq('Test Client')
      expect(client.options).to eq(options)
      expect(client.logger).to eq(options[:logger])
    end
    
    it 'generates a UUID for client ID' do
      expect(client.id).not_to be_nil
      expect(client.id).to match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
    end
  end
  
  describe 'connection' do
    it 'initializes the transport during instantiation' do
      expect(MCP::Protocol).to have_received(:create_transport)
    end
    
    it 'connects to the server' do
      # Reset the mocks
      new_transport = mock_transport
      allow(MCP::Protocol).to receive(:create_transport).and_return(new_transport)
      
      # Create a new client to test connection
      new_client = client_class.new(options)
      
      expect(new_transport).to receive(:connect)
      new_client.connect
    end
    
    it 'sets connected flag to true' do
      client.instance_variable_set(:@connected, false)
      allow(transport).to receive(:connect).and_return(transport)
      
      client.connect
      expect(client.connected?).to be(true)
    end
  end
end