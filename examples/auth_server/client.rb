#!/usr/bin/env ruby
# frozen_string_literal: true

require 'ruby_mcp'
require 'logger'

# Create a logger
logger = Logger.new(STDOUT)
logger.level = Logger::INFO

# Create the client
client = MCP::Client::Client.new(
  url: 'http://localhost:3000/mcp',
  logger: logger
)

# Set up OAuth credentials for the client authorization code flow
client.set_oauth_credentials(
  client_id: 'example-client',
  client_secret: 'example-secret',
  site: 'http://localhost:3000',
  authorize_url: '/oauth/authorize',
  token_url: '/oauth/token',
  redirect_uri: 'http://localhost:8000/callback',
  scopes: ['tools:read', 'tools:call'],
  auto_refresh: true
)

# Generate an auth URL
state = SecureRandom.hex(8)
auth_url = client.authorization_url(state)
puts "Visit this URL to authorize the client: #{auth_url}"

# For this example, we'll bypass the authorization flow and directly set a token
# In a real application, you would need to implement the full OAuth flow
puts "Since this is an example, we'll create a token directly:"

# Create a sample token (this would normally come from the OAuth authorization flow)
token = OAuth2::AccessToken.new(
  OAuth2::Client.new('example-client', 'example-secret'),
  'example_access_token',
  refresh_token: 'example_refresh_token',
  expires_at: Time.now.to_i + 3600,
  params: { 'scope' => 'tools:read tools:call' }
)

# Set the access token directly
client.set_access_token(token)
puts "Token set: #{token.token}"

# Connect to the server
begin
  client.connect
  puts "Connected to server: #{client.server_info[:name]}"
  
  # List available tools
  tools = client.tools.list
  puts "Available tools: #{tools.map { |t| t[:name] }.join(', ')}"
  
  # Call the hello tool
  result = client.tools.call('hello', { name: 'Ruby MCP Client' })
  puts "Result: #{result}"
rescue => e
  puts "Error: #{e.message}"
end