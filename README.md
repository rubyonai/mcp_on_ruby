# MCP on Ruby

<div align="center">

[![Gem Version](https://badge.fury.io/rb/mcp_on_ruby.svg)](https://badge.fury.io/rb/mcp_on_ruby)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ruby Version](https://img.shields.io/badge/Ruby-3.0%2B-red.svg)](https://www.ruby-lang.org/)
[![Build Status](https://github.com/nagstler/mcp_on_ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/nagstler/mcp_on_ruby/actions)

A Ruby implementation of the [Model Context Protocol (MCP)](https://modelcontextprotocol.io) specification, enabling standardized AI application interactions with external tools and data sources.

[Documentation](https://rubydoc.info/gems/mcp_on_ruby) | [Examples](/examples) | [Contributing](#contributing)

</div>

## 📋 Table of Contents

- [Features](#-features)
- [Installation](#-installation)
- [Quick Start](#-quick-start)
  - [Server Setup](#server-setup)
  - [Client Setup](#client-setup)
- [Core Concepts](#-core-concepts)
- [Security](#-security)
- [Advanced Usage](#-advanced-usage)
- [Development](#-development)
- [Contributing](#-contributing)
- [License](#-license)

## ✨ Features

- **Full MCP Protocol Support** - Implements the latest MCP specification
- **Multiple Transport Options** - HTTP and STDIO transports
- **Comprehensive Capabilities**
  - 🛠️ Tools (model-controlled actions)
  - 📚 Resources (application-controlled context)
  - 💬 Prompts (user-controlled interactions)
  - 📁 Roots (filesystem integration)
- **Security First**
  - OAuth 2.1 Authentication
  - JWT Implementation
  - Scope-based Authorization
- **Real-time Communication**
  - Bidirectional messaging
  - Streaming support
  - JSON-RPC 2.0 standard

## 🚀 Installation

Add to your `Gemfile`:

```ruby
gem 'mcp_on_ruby'
```

Then run:

```bash
bundle install
```

Or install directly:

```bash
gem install mcp_on_ruby
```

## 🏁 Quick Start

### Server Setup

Create a basic MCP server with tools:

```ruby
require 'mcp_on_ruby'

server = MCP::Server.new do |s|
  # Define a tool
  s.tool "weather.get_forecast" do |params|
    location = params[:location]
    { forecast: "Sunny", temperature: 72, location: location }
  end
  
  # Add a resource
  s.resource "user.profile" do
    { name: "John", email: "john@example.com" }
  end
end

server.start
```

### Client Setup

Connect to an MCP server:

```ruby
require 'mcp_on_ruby'

client = MCP::Client.new(url: "http://localhost:3000")
client.connect

# List available tools
tools = client.tools.list

# Call a tool
result = client.tools.call("weather.get_forecast", 
  { location: "San Francisco" }
)
```

## 🎯 Core Concepts

### 1. Tools
Model-controlled functions with JSON Schema-defined parameters:

```ruby
server.tools.define('example') do
  parameter :name, :string
  
  execute do |params|
    "Hello, #{params[:name]}!"
  end
end
```

### 2. Resources
Application-controlled data sources:

```ruby
server.resource "user.profile" do
  { name: "John", email: "john@example.com" }
end
```

### 3. Authentication
Secure your server with OAuth 2.1:

```ruby
oauth_provider = MCP::Server::Auth::OAuth.new(
  client_id: 'your-client-id',
  client_secret: 'your-client-secret',
  token_expiry: 3600,
  jwt_secret: 'your-jwt-secret',
  issuer: 'your-server'
)
```

## 🔒 Security

### OAuth 2.1 Implementation
- Token-based authentication
- JWT validation
- Automatic token refresh
- Scope-based authorization

### Permission Management
- Method-level permissions
- Scope requirements
- Middleware architecture

## 📚 Advanced Usage

Check out our [examples directory](/examples) for complete implementations:

- [Simple Server](/examples/simple_server.rb)
- [Authentication](/examples/authentication.rb)
- [Rails Integration](/examples/rails_integration.rb)
- [Streaming](/examples/streaming.rb)

For more advanced topics, visit our [Wiki](https://github.com/nagstler/mcp_on_ruby/wiki).

## 💻 Development

```bash
# Clone the repository
git clone https://github.com/nagstler/mcp_on_ruby.git

# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Start console
bundle exec bin/console
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please read our [Contributing Guide](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE.txt) file for details.

---

<div align="center">
Made with ❤️ for the Ruby community
</div>