# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'MCP::Client::Client' do
  let(:client_class) { MCP::Client::Client }
  let(:options) do
    {
      name: 'Test Client',
      logger: Logger.new(nil)
    }
  end
  
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
  
  describe '#initialize' do
    it 'sets client properties' do
      expect(client.name).to eq('Test Client')
      expect(client.options).to eq(options)
      expect(client.logger).to eq(options[:logger])
    end
    
    it 'generates a UUID for client ID' do
      expect(client.id).not_to be_nil
      expect(client.id).to match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
    end
    
    it 'initializes a transport' do
      expect(MCP::Protocol).to have_received(:create_transport)
    end
  end
  
  describe '#connect' do
    context 'when not already connected' do
      before do
        client.instance_variable_set(:@connected, false)
      end
      
      it 'initializes and connects the transport' do
        expect(transport).to receive(:connect).and_return(transport)
        expect(MCP::Protocol::Connection).to receive(:new).with(transport).and_return(connection)
        expect(connection).to receive(:initialize_connection)
        
        client.connect
      end
      
      it 'sets connected flag to true' do
        client.connect
        expect(client.connected?).to be(true)
      end
      
      it 'stores the connection' do
        client.connect
        expect(client.instance_variable_get(:@connection)).to eq(connection)
      end
    end
    
    context 'when already connected' do
      before do
        client.instance_variable_set(:@connected, true)
      end
      
      it 'returns self without reconnecting' do
        expect(transport).not_to receive(:connect)
        expect(client.connect).to eq(client)
      end
    end
  end
  
  describe '#disconnect' do
    context 'when connected' do
      before do
        client.instance_variable_set(:@connected, true)
        client.instance_variable_set(:@connection, connection)
      end
      
      it 'disconnects the transport' do
        expect(transport).to receive(:disconnect)
        client.disconnect
      end
      
      it 'sets connected flag to false' do
        client.disconnect
        expect(client.connected?).to be(false)
      end
      
      it 'clears the connection' do
        client.disconnect
        expect(client.instance_variable_get(:@connection)).to be_nil
      end
    end
    
    context 'when not connected' do
      before do
        client.instance_variable_set(:@connected, false)
      end
      
      it 'does nothing' do
        expect(transport).not_to receive(:disconnect)
        client.disconnect
      end
    end
  end
  
  describe '#ensure_connected' do
    it 'raises an error if not connected' do
      client.instance_variable_set(:@connected, false)
      
      expect {
        client.send(:ensure_connected)
      }.to raise_error(MCP::Errors::ConnectionError)
    end
    
    it 'does nothing if connected' do
      client.instance_variable_set(:@connected, true)
      
      expect {
        client.send(:ensure_connected)
      }.not_to raise_error
    end
  end
end