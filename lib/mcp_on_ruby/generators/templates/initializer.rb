# MCP on Ruby configuration
McpOnRuby.configure do |config|
  # Logging level
  config.log_level = Rails.logger.level
  
  # MCP endpoint path
  config.path = '/mcp'
  
  # Authentication (set to true for production)
  config.authentication_required = false
  config.authentication_token = ENV['MCP_AUTH_TOKEN']
  
  # Security settings
  config.allowed_origins = []  # Empty means allow all origins
  config.localhost_only = Rails.env.development?
  config.dns_rebinding_protection = true
  
  # Rate limiting (requests per minute per IP)
  config.rate_limit_per_minute = 60
  
  # Features
  config.enable_sse = true
  config.cors_enabled = true
end

# Enable MCP server in Rails
Rails.application.configure do
  config.mcp.enabled = true
  config.mcp.auto_register_tools = true
  config.mcp.auto_register_resources = true
end

# Mount MCP server (alternative to route-based mounting)
# Rails.application.config.after_initialize do
#   McpOnRuby.mount_in_rails(Rails.application) do |server|
#     # Manual tool/resource registration if needed
#     # server.tool 'custom_tool', 'Description' do |args|
#     #   { result: 'Custom logic here' }
#     # end
#   end
# end