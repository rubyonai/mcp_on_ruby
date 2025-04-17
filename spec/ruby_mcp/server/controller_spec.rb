# spec/ruby_mcp/server/controller_spec.rb
require 'spec_helper'

RSpec.describe RubyMCP::Server::Controller do
  let(:config) { RubyMCP::Configuration.new }
  let(:controller) { described_class.new(config) }
  
  describe "#initialize" do
    it "creates an app with the provided configuration" do
      expect(controller.instance_variable_get(:@config)).to eq(config)
      expect(controller.instance_variable_get(:@app)).to be_a(RubyMCP::Server::App)
    end
  end
  
  # We can't easily test #start since it runs a server, but we can test
  # that the method exists and check its basic configuration
  describe "#start" do
    it "configures the server with the correct host and port" do
      # Mock Rack::Handler::WEBrick to prevent actual server start
      expect(Rack::Handler::WEBrick).to receive(:run).with(
        anything, hash_including(Host: config.server_host, Port: config.server_port)
      )
      
      controller.start
    end
  end
end