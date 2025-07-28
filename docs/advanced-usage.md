# Advanced Usage

## Custom Authorization

```ruby
class ApplicationTool < McpOnRuby::Tool
  def authorize(context)
    token = context[:auth_token]
    user = authenticate_token(token)
    user&.has_permission?(:mcp_access)
  end

  private

  def authenticate_token(token)
    # Your authentication logic
    JWT.decode(token, Rails.application.secret_key_base).first
  rescue JWT::DecodeError
    nil
  end
end
```

## Resource Caching

```ruby
class ApplicationResource < McpOnRuby::Resource
  def read(params = {}, context = {})
    cache_key = "mcp:#{uri}:#{params.hash}"
    Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      super
    end
  end
end
```

## Manual Server Configuration

```ruby
# For advanced scenarios where auto-registration isn't sufficient
McpOnRuby.mount_in_rails(Rails.application) do |server|
  # Register tools manually
  server.register_tool(CustomTool.new)
  
  # Define tools with DSL
  server.tool 'database_query', 'Execute read-only database queries' do |args|
    query = args['query']
    raise 'Only SELECT allowed' unless query.strip.upcase.start_with?('SELECT')
    
    result = ActiveRecord::Base.connection.execute(query)
    { rows: result.to_a }
  end
  
  # Define resources with DSL
  server.resource 'health' do
    {
      status: 'healthy',
      database: database_healthy?,
      redis: redis_healthy?,
      timestamp: Time.current
    }
  end
end
```

## Production Configuration

### Security Setup

```ruby
# config/initializers/mcp_on_ruby.rb
McpOnRuby.configure do |config|
  # Authentication
  config.authentication_required = true
  config.authentication_token = ENV['MCP_AUTH_TOKEN']
  
  # Security
  config.dns_rebinding_protection = true
  config.allowed_origins = [
    ENV['ALLOWED_ORIGIN'],
    /\A#{Regexp.escape(ENV['DOMAIN'])}\z/
  ]
  config.localhost_only = false
  
  # Rate limiting
  config.rate_limit_per_minute = 100
  
  # Features
  config.cors_enabled = true
end
```

### Monitoring & Logging

```ruby
class ApplicationTool < McpOnRuby::Tool
  def call(arguments = {}, context = {})
    start_time = Time.current
    result = super
    duration = Time.current - start_time
    
    Rails.logger.info("MCP Tool executed", {
      tool: name,
      duration: duration,
      success: !result.key?(:error),
      user_ip: context[:remote_ip]
    })
    
    result
  end
end
```

### Error Monitoring

```ruby
# config/initializers/mcp_on_ruby.rb
class CustomTool < ApplicationTool
  def execute(arguments, context)
    # Your tool logic
  rescue => error
    # Report to error monitoring service
    Bugsnag.notify(error, {
      tool: name,
      arguments: arguments,
      context: context
    })
    
    raise
  end
end
```