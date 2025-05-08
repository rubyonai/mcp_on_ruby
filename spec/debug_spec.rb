# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Module Debug' do
  it 'checks the loaded modules' do
    puts "Defined constants: #{Object.constants.grep(/MCP/).join(', ')}"
    puts "MCP included modules: #{MCP.included_modules.map(&:to_s).join(', ')}"
    puts "MCP singleton methods: #{MCP.singleton_methods.map(&:to_s).join(', ')}"
    puts "MCP constants: #{MCP.constants.join(', ')}"
    
    # Check if specific modules are defined
    puts "MCP::Client defined? #{defined?(MCP::Client) != nil}"
    puts "MCP::Server defined? #{defined?(MCP::Server) != nil}"
    puts "MCP::Protocol defined? #{defined?(MCP::Protocol) != nil}"
    
    # Check module paths
    begin
      puts "MCP::Client location: #{MCP::Client.name} at #{MCP::Client.instance_method(:initialize).source_location.first}" rescue puts "Failed to get MCP::Client location"
      puts "MCP::Server location: #{MCP::Server.name} at #{MCP::Server.instance_method(:initialize).source_location.first}" rescue puts "Failed to get MCP::Server location"
      puts "MCP::Protocol location: #{MCP::Protocol.name} at #{MCP::Protocol.methods.first.source_location.first}" rescue puts "Failed to get MCP::Protocol location"
    rescue => e
      puts "Error getting locations: #{e.message}"
    end
    
    expect(1).to eq(1)
  end
end