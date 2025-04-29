# frozen_string_literal: true

# config/initializers/ruby_mcp.rb

require 'ruby_mcp'

Rails.application.config.to_prepare do
  RubyMCP.configure do |config|
    # Configure providers
    config.providers = {
      openai: { api_key: ENV['OPENAI_API_KEY'] },
      anthropic: { api_key: ENV['ANTHROPIC_API_KEY'] }
    }

    # Use ActiveRecord storage with Rails database
    config.storage = :active_record
    config.active_record = {
      # Uses the Rails database connection automatically
      table_prefix: "mcp_#{Rails.env}_"  # Environment-specific prefix
    }

    # Enable authentication in production
    if Rails.env.production?
      config.auth_required = true
      config.jwt_secret = ENV['JWT_SECRET']
    end
  end

  # Log configuration
  Rails.logger.info "Configured RubyMCP with providers: #{RubyMCP.configuration.providers.keys.join(', ')}"
  Rails.logger.info "Using ActiveRecord storage with prefix: #{RubyMCP.configuration.active_record[:table_prefix]}"
end