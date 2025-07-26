#!/usr/bin/env ruby
# frozen_string_literal: true

require 'mcp_on_ruby'
require 'logger'

# Create a logger
logger = Logger.new(STDOUT)
logger.level = Logger::INFO

# Create the OAuth provider
oauth_provider = MCP::Server::Auth::OAuth.new(
  client_id: 'example-client',
  client_secret: 'example-secret',
  token_expiry: 3600,
  jwt_secret: 'example-jwt-secret',
  issuer: 'example-server',
  scopes: ['tools:read', 'tools:call', 'resources:read', 'resources:call']
)

# Create the permissions manager
permissions = MCP::Server::Auth::Permissions.new
permissions.add_method('tools/list', ['tools:read'])
permissions.add_method('tools/call', ['tools:call'])
permissions.add_method('resources/list', ['resources:read'])
permissions.add_method('resources/call', ['resources:call'])

# Create the server with authentication
server = MCP::Server::Server.new(
  name: 'Example Authenticated MCP Server',
  logger: logger,
  transport_options: {
    transport: :http,
    host: 'localhost',
    port: 3000,
    path: '/mcp'
  }
)

# Set the authentication provider
server.set_auth_provider(oauth_provider, permissions)

# Define a tool
server.tools.define('hello') do
  parameter :name, :string, description: 'Your name'
  
  execute do |params|
    "Hello, #{params[:name] || 'World'}!"
  end
end

# Start the server
server.start

# Wait for interrupt
puts "Server started on http://localhost:3000/mcp"
puts "Press Ctrl+C to stop"

trap('INT') do
  puts "\nShutting down..."
  server.stop
  exit
end

# Keep the main thread alive
sleep