# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'MCP::Client::Client' do
  subject(:client_class) { MCP::Client::Client }
  
  before do
    # We need to stub dependencies to avoid actual connections
    allow(MCP::Protocol).to receive(:create_transport).and_return(double(
      connect: double,
      connected?: true,
      disconnect: nil,
      on_event: nil,
      send_message: {}
    ))
  end
  
  it 'exists as a constant' do
    expect(defined?(MCP::Client::Client)).to eq('constant')
  end
  
  it 'is a class' do
    expect(client_class.is_a?(Class)).to be(true)
  end
  
  it 'can be instantiated with options' do
    options = {
      name: 'Test Client',
      logger: Logger.new(nil)
    }
    expect { client_class.new(options) }.not_to raise_error
  end
end