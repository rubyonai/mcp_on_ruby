# MCP on Ruby

<div align="center">

[![Gem Version](https://badge.fury.io/rb/mcp_on_ruby.svg)](https://badge.fury.io/rb/mcp_on_ruby)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

<strong>Ruby implementation of the Model Context Protocol (MCP) specification</strong>
</div>

## Overview

The [Model Context Protocol](https://modelcontextprotocol.io) provides a standardized way for AI applications to interact with external tools and data sources. This library implements the MCP specification in Ruby, allowing developers to create both MCP servers and clients.

## Features

- **Full MCP 2025-03-26 Protocol Support**: Implements the latest MCP specification
- **JSON-RPC 2.0 Communication**: Bidirectional messaging using the JSON-RPC standard
- **Transport Options**: HTTP and STDIO transports for maximum flexibility
- **Server Capabilities**: 
  - Tools (model-controlled actions)
  - Resources (application-controlled context)
  - Prompts (user-controlled interactions)
  - Roots (filesystem integration)
- **Client Integration**: Connect to any MCP-compatible server
- **OAuth 2.1 Authentication**: Secure access to remote servers
- **Streaming Support**: Real-time bidirectional communication

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'mcp_on_ruby'
```

And then execute:

```
$ bundle install
```

Or install it yourself as:

```
$ gem install mcp_on_ruby
```

## Quick Start: Server

Create a simple MCP server with tools:

```ruby
require 'mcp_on_ruby'

# Create a server with tools
server = MCP::Server.new do |s|
  # Define a tool
  s.tool "weather.get_forecast" do |params|
    location = params[:location]
    # ... fetch weather data ...
    { forecast: "Sunny", temperature: 72, location: location }
  end
  
  # Add a resource
  s.resource "user.profile" do
    { name: "John", email: "john@example.com" }
  end
end

# Start the server
server.start
```

## Quick Start: Client

Connect to an MCP server and use its tools:

```ruby
require 'mcp_on_ruby'

# Create a client
client = MCP::Client.new(url: "http://localhost:3000")

# Connect to the server
client.connect

# List available tools
tools = client.list_tools
puts tools

# Call a tool
result = client.call_tool("weather.get_forecast", location: "San Francisco")
puts result.inspect

# Get a resource
profile = client.get_resource("user.profile")
puts profile.inspect

# Disconnect
client.disconnect
```

## MCP Implementation

This library is an implementation of the Model Context Protocol specification:

### 1. Server Framework
- **JSON-RPC 2.0 interface**
- **Bidirectional communication** support
- **Connection/session management**

### 2. Four Capability Types
- **Tools**: Model-controlled functions with JSON Schema-defined parameters
- **Resources**: Application-controlled data sources models can access
- **Prompts**: Interactive templates requiring user input
- **Roots**: File system access points with appropriate permissions

### 3. Method Handlers
- `tools/list` - Returns available tools
- `tools/call` - Executes a specific tool
- `resources/list` - Returns available resources
- `resources/get` - Retrieves data from a resource
- `prompts/list` - Returns available prompts
- `prompts/show` - Displays a prompt template
- `roots/list` - Returns available filesystem roots
- `roots/read` - Reads files from a root directory
- ...and all other required MCP methods

## Architecture

MCP on Ruby follows the MCP specification's architecture:

1. **Protocol Layer**: JSON-RPC 2.0 communication over multiple transports
2. **Server**: Exposes tools, resources, and prompts to clients
3. **Client**: Connects to servers and uses their capabilities
4. **Authentication**: OAuth 2.1 for secure remote connections

## Advanced Usage

See the [wiki](https://github.com/nagstler/mcp_on_ruby/wiki) for advanced usage, including:

- Creating complex tool hierarchies
- Implementing custom authentication
- Streaming responses
- Working with resources and prompts
- File system integration with roots

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/nagstler/mcp_on_ruby.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).