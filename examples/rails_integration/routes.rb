# frozen_string_literal: true

# config/routes.rb

Rails.application.routes.draw do
  # Mount RubyMCP at /api/mcp
  mount_mcp_at = '/api/mcp'

  Rails.application.config.middleware.use Rack::Config do |env|
    env['SCRIPT_NAME'] = mount_mcp_at if env['PATH_INFO'].start_with?(mount_mcp_at)
  end

  mount RubyMCP::Server::App.new.rack_app, at: mount_mcp_at

  # Rest of your routes
  # ...
end
