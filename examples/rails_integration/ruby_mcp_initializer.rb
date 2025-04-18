# frozen_string_literal: true

# config/initializers/ruby_mcp.rb

require 'ruby_mcp'

Rails.application.config.to_prepare do
  RubyMCP.configure do |config|
    config.providers = {
      openai: { api_key: ENV['OPENAI_API_KEY'] },
      anthropic: { api_key: ENV['ANTHROPIC_API_KEY'] }
    }

    # Use memory storage in development
    if Rails.env.development? || Rails.env.test?
      Rails.logger.debug('Development/Test environment loaded')
    else
      # Consider Redis or another persistent storage for production
      Rails.logger.debug('Persistent storage for production')
    end
    config.storage = :memory

    # Enable authentication in production
    if Rails.env.production?
      config.auth_required = true
      config.jwt_secret = ENV['JWT_SECRET']
    end
  end

  # Log configuration
  Rails.logger.info "Configured RubyMCP with providers: #{RubyMCP.configuration.providers.keys.join(', ')}"
end
