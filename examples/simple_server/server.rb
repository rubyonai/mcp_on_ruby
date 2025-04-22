# frozen_string_literal: true
$LOAD_PATH.unshift File.expand_path('../../lib', __dir__)

require 'ruby_mcp'
require 'dotenv'

# Load environment variables from .env file
Dotenv.load('../../.env')

# Configure RubyMCP
RubyMCP.configure do |config|
  config.providers = {
    openai: { api_key: ENV['OPENAI_API_KEY'] },
    anthropic: { api_key: ENV['ANTHROPIC_API_KEY'] }
  }
  config.storage = :memory
  config.server_port = 3000
  config.server_host = '0.0.0.0'

  # Uncomment to enable authentication
  # config.auth_required = true
  # config.jwt_secret = ENV["JWT_SECRET"]
end

# Log configuration
RubyMCP.logger.info "Starting RubyMCP server with providers: #{RubyMCP.configuration.providers.keys.join(', ')}"

# Start the server
server = RubyMCP::Server::Controller.new
server.start
