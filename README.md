# MCP on Ruby

<div align="center">

[![Gem Version](https://badge.fury.io/rb/mcp_on_ruby.svg)](https://badge.fury.io/rb/mcp_on_ruby)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ruby Version](https://img.shields.io/badge/Ruby-2.7%2B-red.svg)](https://www.ruby-lang.org/)

**Model Context Protocol (MCP) server for Rails applications**

Build AI-powered integrations with tools, resources, authentication, and real-time capabilities.

[Documentation](https://rubydoc.info/gems/mcp_on_ruby) | [Examples](#examples) | [Contributing](#contributing)

</div>

---

## Features

🚀 **Production-Ready** - Authentication, rate limiting, error handling, security  
🔧 **Rails Integration** - Generators, autoloading, middleware, Railtie  
🛠️ **Tools System** - AI-callable functions with JSON Schema validation  
📊 **Resources System** - Data exposure with URI templating  
🔒 **Security** - DNS rebinding protection, CORS, token authentication  
⚡ **Real-time** - Server-Sent Events (SSE) foundation (full implementation coming soon)  
🎯 **Developer-Friendly** - Clean DSL, generators, testing support  

## Installation

Add to your `Gemfile`:

```ruby
gem 'mcp_on_ruby'
```

Then run:

```bash
bundle install
rails generate mcp_on_ruby:install
```

## Quick Start

### 1. Install and Configure

```bash
# Generate MCP server files
rails generate mcp_on_ruby:install

# Create a tool
rails generate mcp_on_ruby:tool UserManager --description "Manage application users"

# Create a resource  
rails generate mcp_on_ruby:resource UserStats --uri "users/{id}/stats" --template
```

### 2. Configure MCP Server

```ruby
# config/initializers/mcp_on_ruby.rb
McpOnRuby.configure do |config|
  config.authentication_required = true
  config.authentication_token = ENV['MCP_AUTH_TOKEN']
  config.rate_limit_per_minute = 60
  config.allowed_origins = [/\.yourdomain\.com$/]
end

Rails.application.configure do
  config.mcp.enabled = true
  config.mcp.auto_register_tools = true
  config.mcp.auto_register_resources = true
end
```

### 3. Create Tools

```ruby
# app/tools/user_manager_tool.rb
class UserManagerTool < ApplicationTool
  def initialize
    super(
      name: 'user_manager',
      description: 'Manage application users',
      input_schema: {
        type: 'object',
        properties: {
          action: { type: 'string', enum: ['create', 'update', 'delete'] },
          user_id: { type: 'integer' },
          attributes: { type: 'object' }
        },
        required: ['action']
      }
    )
  end

  protected

  def execute(arguments, context)
    case arguments['action']
    when 'create'
      user = User.create!(arguments['attributes'])
      { success: true, user: user.as_json }
    when 'update'
      user = User.find(arguments['user_id'])
      user.update!(arguments['attributes'])
      { success: true, user: user.as_json }
    else
      { error: 'Unsupported action' }
    end
  end

  def authorize(context)
    # Add your authorization logic
    context[:authenticated] == true
  end
end
```

### 4. Create Resources

```ruby
# app/resources/user_stats_resource.rb
class UserStatsResource < ApplicationResource
  def initialize
    super(
      uri: 'users/{id}/stats',
      name: 'User Statistics',
      description: 'Get detailed user statistics',
      mime_type: 'application/json'
    )
  end

  protected

  def fetch_content(params, context)
    user = User.find(params['id'])
    
    {
      user_id: user.id,
      statistics: {
        posts_count: user.posts.count,
        comments_count: user.comments.count,
        last_login: user.last_login_at,
        account_created: user.created_at
      },
      generated_at: Time.current.iso8601
    }
  end

  def authorize(context)
    # Check if user can access this data
    context[:authenticated] == true
  end
end
```

### 5. Start Your Server

```bash
rails server
# MCP server available at http://localhost:3000/mcp
```

## Architecture

### Clean Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Rails App                            │
├─────────────────────────────────────────────────────────────┤
│  app/tools/          │  app/resources/                      │
│  ├── application_tool.rb     ├── application_resource.rb    │
│  ├── user_manager_tool.rb    ├── user_stats_resource.rb     │
│  └── ...                     └── ...                        │
├─────────────────────────────────────────────────────────────┤
│                    MCP Server Core                          │
│  ┌─────────────────┐ ┌─────────────────┐ ┌──────────────┐   │
│  │     Tools       │ │    Resources    │ │  Transport   │   │
│  │  - Validation   │ │  - Templating   │ │  - HTTP      │   │
│  │  - Authorization│ │  - Authorization│ │  - SSE       │   │
│  │  - Execution    │ │  - Content      │ │  - Security  │   │
│  └─────────────────┘ └─────────────────┘ └──────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                  JSON-RPC Protocol                          │
└─────────────────────────────────────────────────────────────┘
```

## Advanced Usage

### Custom Authorization

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

### Resource Caching

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

### Real-time Updates with SSE (Coming Soon)

```ruby
# SSE implementation is planned for future release
# Currently logs resource updates
class Post < ApplicationRecord
  after_create :notify_mcp_clients

  private

  def notify_mcp_clients
    # Currently logs the update, SSE broadcasting coming soon
    McpOnRuby.broadcast_resource_update('posts')
  end
end
```

### Manual Server Configuration

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

## Testing

### RSpec Integration

```ruby
# spec/tools/user_manager_tool_spec.rb
require 'rails_helper'

RSpec.describe UserManagerTool do
  subject(:tool) { described_class.new }

  describe '#execute' do
    context 'creating a user' do
      let(:arguments) do
        {
          'action' => 'create',
          'attributes' => { 'name' => 'John Doe', 'email' => 'john@example.com' }
        }
      end
      
      it 'creates user successfully' do
        result = tool.call(arguments, { authenticated: true })
        
        expect(result[:success]).to be true
        expect(result[:user]['name']).to eq 'John Doe'
      end
    end
  end
end
```

### Integration Testing

```ruby
# spec/integration/mcp_server_spec.rb
require 'rails_helper'

RSpec.describe 'MCP Server Integration' do
  let(:server) { Rails.application.config.mcp_server }

  it 'handles tool calls' do
    request = {
      jsonrpc: '2.0',
      method: 'tools/call',
      params: { name: 'user_manager', arguments: { action: 'create' } },
      id: 1
    }

    response = server.handle_request(request.to_json)
    parsed = JSON.parse(response)

    expect(parsed['result']).to be_present
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
  config.enable_sse = true
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

## API Reference

### Server Methods

```ruby
server = McpOnRuby.server do |s|
  s.tool(name, description, input_schema, **options, &block)
  s.resource(uri, **options, &block)
  s.register_tool(tool_instance)
  s.register_resource(resource_instance)
end

# Handle requests
server.handle_request(json_string, context)
```

### Tool Class

```ruby
class MyTool < McpOnRuby::Tool
  def initialize(name:, description: '', input_schema: {}, **options)
  def execute(arguments, context) # Override this
  def authorize(context) # Optional override
end
```

### Resource Class

```ruby
class MyResource < McpOnRuby::Resource
  def initialize(uri:, name: nil, description: '', mime_type: 'application/json', **options)
  def fetch_content(params, context) # Override this
  def authorize(context) # Optional override
end
```

## Examples

See [examples directory](/examples) for complete working examples:

- **Basic Rails Integration** - Simple setup with tools and resources
- **Authentication Examples** - JWT and token-based auth
- **Advanced Tools** - Database operations, file processing
- **Real-time Resources** - SSE updates and live data
- **Production Setup** - Security, monitoring, deployment

## Requirements

- Ruby 2.7.0 or higher
- Rails 6.0 or higher (for full integration)
- JSON Schema validation support

## Dependencies

Production dependencies (minimal footprint):
- `json-schema` (~> 3.0) - JSON Schema validation
- `rack` (~> 2.2) - HTTP transport layer
- `webrick` (~> 1.7) - HTTP server

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Write tests for your changes
4. Ensure all tests pass (`bundle exec rspec`)
5. Commit your changes (`git commit -am 'Add some feature'`)
6. Push to the branch (`git push origin my-new-feature`)
7. Create a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE.txt](LICENSE.txt) file for details.

## 🙏 Acknowledgments

- The [Model Context Protocol](https://modelcontextprotocol.io) team at Anthropic for creating the specification
- The Ruby on Rails community for inspiration and conventions

---

<div align="center">

Made with ❤️ for the Ruby community

</div>