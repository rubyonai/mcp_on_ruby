<div align="center">

# RubyMCP

[![Build](https://github.com/nagstler/ruby_mcp/actions/workflows/build.yml/badge.svg)](https://github.com/nagstler/ruby_mcp/actions/workflows/build.yml)
[![Test](https://github.com/nagstler/ruby_mcp/actions/workflows/test.yml/badge.svg)](https://github.com/nagstler/ruby_mcp/actions/workflows/test.yml)
[![codecov](https://codecov.io/github/nagstler/ruby_mcp/graph/badge.svg?token=SG4EJEIHW3)](https://codecov.io/github/nagstler/ruby_mcp)

<strong>The Ruby way to build MCP servers and clients.</strong>
</div>

## Introduction

The [Model Context Protocol (MCP)](https://modelcontextprotocol.io) provides a standardized way for applications to interact with various language model providers (like OpenAI, Anthropic, etc.) through a consistent interface. This gem implements an MCP server in Ruby, allowing Ruby applications to leverage the benefits of this protocol.

![design-1](https://github.com/user-attachments/assets/c1d76dc9-6aea-4cbb-a779-f0f7d85e71fb)

## Why RubyMCP?

RubyMCP provides a Ruby implementation of the Model Context Protocol:

- Standard API for multiple LLM providers
- Context management for conversations
- Support for streaming responses
- File handling capabilities
- Tool calling support
- Authentication
- Schema validation using dry-schema

The library is designed to be straightforward to use while maintaining full compatibility with the MCP specification.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ruby_mcp'
```

And then execute:

```
$ bundle install
```

Or install it yourself as:

```
$ gem install ruby_mcp
```

## Quick Start

Here's how to get a basic MCP server running:

```ruby
require 'ruby_mcp'

# Configure RubyMCP
RubyMCP.configure do |config|
  config.providers = {
    openai: { api_key: ENV['OPENAI_API_KEY'] },
    anthropic: { api_key: ENV['ANTHROPIC_API_KEY'] }
  }
end

# Start the MCP server
server = RubyMCP::Server::Controller.new
server.start  # This will block the current thread
```

### Interactive Demo

The repository includes an interactive demo that walks through all the key MCP concepts:

First, start the example server:

```bash
cd examples/simple_server
ruby server.rb
```

Then, in a separate terminal, run the client:

```bash
cd examples/simple_server
ruby client.rb
```
This demo provides a guided tour of the MCP functionality, showing each step of creating contexts, adding messages, and generating responses with detailed explanations.

## Configuration Options

RubyMCP offers several configuration options:

```ruby
RubyMCP.configure do |config|
  # LLM Provider configurations
  config.providers = {
    openai: { 
      api_key: ENV['OPENAI_API_KEY'],
      api_base: 'https://api.openai.com/v1' # Optional
    },
    anthropic: { 
      api_key: ENV['ANTHROPIC_API_KEY'] 
    }
  }
  
  # Storage backend (:memory, :redis, :active_record, or custom)
  config.storage = :memory
  
  # Server settings
  config.server_port = 3000
  config.server_host = "0.0.0.0"
  
  # Authentication settings
  config.auth_required = false
  config.jwt_secret = ENV['JWT_SECRET']
  config.token_expiry = 3600 # 1 hour
  
  # Limits
  config.max_contexts = 1000
end
```

## Server Endpoints

The MCP server provides the following endpoints:

### Engines
- `GET /engines` - List available language models

### Contexts
- `POST /contexts` - Create a new conversation context
- `GET /contexts` - List existing contexts
- `GET /contexts/:id` - Get details of a specific context
- `DELETE /contexts/:id` - Delete a context

### Messages
- `POST /messages` - Add a message to a context

### Generation
- `POST /generate` - Generate a response from a language model
- `POST /generate/stream` - Stream a response with incremental updates

### Content
- `POST /content` - Upload content (files)
- `GET /content/:context_id/:id` - Retrieve uploaded content

## Detailed Usage

### Creating a Context

```ruby
# Using the HTTP API
response = Faraday.post(
  "http://localhost:3000/contexts",
  {
    messages: [
      {
        role: "system",
        content: "You are a helpful assistant."
      }
    ],
    metadata: {
      user_id: "user_123",
      conversation_name: "Technical Support"
    }
  }.to_json,
  "Content-Type" => "application/json"
)

context_id = JSON.parse(response.body)["id"]
```

### Adding a Message

```ruby
Faraday.post(
  "http://localhost:3000/messages",
  {
    context_id: context_id,
    role: "user",
    content: "What is the capital of France?"
  }.to_json,
  "Content-Type" => "application/json"
)
```

### Generating a Response

```ruby
response = Faraday.post(
  "http://localhost:3000/generate",
  {
    context_id: context_id,
    engine_id: "anthropic/claude-3-sonnet-20240229",
    max_tokens: 1000,
    temperature: 0.7
  }.to_json,
  "Content-Type" => "application/json"
)

assistant_response = JSON.parse(response.body)["content"]
```

### Streaming a Response

```ruby
conn = Faraday.new do |f|
  f.request :json
  f.response :json
  f.adapter :net_http
end

conn.post("http://localhost:3000/generate/stream") do |req|
  req.headers["Content-Type"] = "application/json"
  req.body = {
    context_id: context_id,
    engine_id: "openai/gpt-4",
    temperature: 0.7
  }.to_json
  
  req.options.on_data = Proc.new do |chunk, size, total|
    event_data = chunk.split("data: ").last.strip
    next if event_data.empty? || event_data == "[DONE]"
    
    event = JSON.parse(event_data)
    if event["event"] == "generation.content" && event["content"]
      print event["content"]
    end
  end
end
```

### Uploading Content

```ruby
file_data = Base64.strict_encode64(File.read("example.pdf"))

Faraday.post(
  "http://localhost:3000/content",
  {
    context_id: context_id,
    type: "file",
    filename: "example.pdf",
    content_type: "application/pdf",
    file_data: file_data
  }.to_json,
  "Content-Type" => "application/json"
)
```

### Using Tool Calls

```ruby
tools = [
  {
    type: "function",
    function: {
      name: "get_weather",
      description: "Get the current weather for a location",
      parameters: {
        type: "object",
        properties: {
          location: {
            type: "string",
            description: "City and state, e.g., San Francisco, CA"
          }
        },
        required: ["location"]
      }
    }
  }
]

response = Faraday.post(
  "http://localhost:3000/generate",
  {
    context_id: context_id,
    engine_id: "openai/gpt-4",
    tools: tools
  }.to_json,
  "Content-Type" => "application/json"
)

if response.body["tool_calls"]
  # Handle tool calls
  tool_calls = response.body["tool_calls"]
  # Process tool calls and add tool response message
end
```

## Rails Integration

For Rails applications, create an initializer at `config/initializers/ruby_mcp.rb`:

```ruby
RubyMCP.configure do |config|
  config.providers = {
    openai: { api_key: ENV['OPENAI_API_KEY'] },
    anthropic: { api_key: ENV['ANTHROPIC_API_KEY'] }
  }
  
  # Use memory storage in development, consider persistent storage in production
  if Rails.env.development? || Rails.env.test?
    config.storage = :memory
  else
    config.storage = :memory  # Replace with persistent option when implemented
  end
  
  # Enable authentication in production
  if Rails.env.production?
    config.auth_required = true
    config.jwt_secret = ENV["JWT_SECRET"]
  end
end
```

And mount the server in your `config/routes.rb` file:

```ruby
Rails.application.routes.draw do
  # Mount RubyMCP at /api/mcp
  mount_mcp_at = "/api/mcp"
  
  Rails.application.config.middleware.use Rack::Config do |env|
    env["SCRIPT_NAME"] = mount_mcp_at if env["PATH_INFO"].start_with?(mount_mcp_at)
  end
  
  mount RubyMCP::Server::App.new.rack_app, at: mount_mcp_at
  
  # Rest of your routes
  # ...
end
```

## Custom Storage Backend

You can implement custom storage backends by extending the base storage class:

```ruby
class RedisStorage < RubyMCP::Storage::Base
  def initialize(options = {})
    super
    @redis = Redis.new(options)
  end
  
  def create_context(context)
    @redis.set("context:#{context.id}", JSON.dump(context.to_h))
    context
  end
  
  def get_context(context_id)
    data = @redis.get("context:#{context_id}")
    raise RubyMCP::Errors::ContextError, "Context not found: #{context_id}" unless data
    
    hash = JSON.parse(data, symbolize_names: true)
    
    # Create message objects
    messages = hash[:messages].map do |msg|
      RubyMCP::Models::Message.new(
        role: msg[:role],
        content: msg[:content],
        id: msg[:id],
        metadata: msg[:metadata]
      )
    end
    
    # Create the context
    RubyMCP::Models::Context.new(
      id: hash[:id],
      messages: messages,
      metadata: hash[:metadata]
    )
  end
  
  # Implement other required methods...
end

# Configure RubyMCP to use your custom storage
RubyMCP.configure do |config|
  config.storage = RedisStorage.new(url: ENV["REDIS_URL"])
end
```

## Authentication

To enable JWT authentication:

```ruby
RubyMCP.configure do |config|
  config.auth_required = true
  config.jwt_secret = ENV['JWT_SECRET']
  config.token_expiry = 3600 # 1 hour
end
```

Then, create and use JWT tokens:

```ruby
# Generate a token
require 'jwt'

payload = {
  sub: "user_123",
  exp: Time.now.to_i + 3600
}

token = JWT.encode(payload, ENV['JWT_SECRET'], 'HS256')

# Use the token in requests
conn = Faraday.new do |f|
  f.request :json
  f.response :json
  f.adapter :net_http
end

conn.get("http://localhost:3000/contexts") do |req|
  req.headers["Authorization"] = "Bearer #{token}"
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

### Running Tests

```
bundle exec rspec
```

### Local Development Server

```
bundle exec ruby examples/simple_server/server.rb
```

## Roadmap

While RubyMCP is functional for basic use cases, there are several areas planned for improvement:

- [ ] Persistent storage backends (Redis, ActiveRecord)
- [ ] Complete test coverage, including integration tests
- [ ] Improved error handling and recovery strategies
- [ ] Rate limiting for provider APIs
- [ ] Proper tokenization for context window management
- [ ] More robust streaming implementation
- [ ] Additional provider integrations

:heart: Contributions in any of these areas are welcome!

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/my-new-feature`)
5. Create a new Pull Request

Bug reports and pull requests are welcome on GitHub at https://github.com/nagstler/ruby_mcp.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
