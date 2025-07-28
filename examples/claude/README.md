# Claude Desktop Integration with MCP on Ruby

This example demonstrates how to connect Claude Desktop to your Rails application using MCP on Ruby. We'll walk through the complete setup process that bridges the protocol difference between Claude Desktop (stdio) and Rails (HTTP).

## The Challenge

Claude Desktop communicates with MCP servers using **stdio** (standard input/output), but MCP on Ruby runs as an **HTTP server** within your Rails application. We need a bridge to convert between these two protocols.

## Complete Setup Guide

### Step 1: Prepare Your Rails Application

1. **Add MCP on Ruby to your Rails app:**
   ```bash
   # In your Rails app directory
   bundle add mcp_on_ruby
   rails generate mcp_on_ruby:install
   ```

2. **Configure MCP settings:**
   ```ruby
   # config/initializers/mcp_on_ruby.rb
   McpOnRuby.configure do |config|
     config.authentication_required = true
     config.authentication_token = 'my-secure-token'
     config.rate_limit_per_minute = 60
   end
   
   Rails.application.configure do
     config.mcp.enabled = true
     config.mcp.auto_register_tools = true
   end
   ```

3. **Create a sample tool for testing:**
   ```bash
   rails generate mcp_on_ruby:tool UserManager --description "Manage application users"
   ```

   This creates `app/tools/user_manager_tool.rb`. You can customize it or use the default implementation to test the connection.

### Step 2: Set Up the Bridge Script

1. **Copy the bridge script:**
   Copy `claude-bridge.js` from this directory to your preferred location (e.g., `~/mcp-bridge/claude-bridge.js`)

2. **Make it executable:**
   ```bash
   chmod +x ~/mcp-bridge/claude-bridge.js
   ```

3. **Update the bridge script configuration:**
   Edit the top of `claude-bridge.js` to match your setup:
   ```javascript
   const RAILS_PORT = 3001;  // Your Rails server port
   const AUTH_TOKEN = 'my-secure-token';  // Must match your Rails config
   ```

### Step 3: Configure Claude Desktop

1. **Locate Claude Desktop config file:**
   - **macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
   - **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

2. **Add your MCP server configuration:**
   ```json
   {
     "mcpServers": {
       "my-rails-app": {
         "command": "node",
         "args": ["/Users/yourusername/mcp-bridge/claude-bridge.js"]
       }
     }
   }
   ```
   
   Replace `/Users/yourusername/mcp-bridge/claude-bridge.js` with the actual path to your bridge script.

### Step 4: Start Everything

1. **Start your Rails server:**
   ```bash
   cd your-rails-app
   rails server -p 3001
   ```

2. **Restart Claude Desktop** to load the new MCP server configuration

### Step 5: Test the Integration

1. Open Claude Desktop
2. Look for your MCP tools in the available tools (they should appear automatically)
3. Try asking Claude to use your tools:
   - "Use the user manager tool to help me understand what it does"
   - "What tools are available from my Rails application?"
   - Test any specific functionality you've implemented in your tools

## How the Bridge Works

```
┌─────────────────┐    stdio     ┌─────────────────┐    HTTP     ┌─────────────────┐
│   Claude        │ ←──────────→ │   Bridge        │ ←─────────→ │   Rails MCP     │
│   Desktop       │              │   Script        │             │   Server        │
└─────────────────┘              └─────────────────┘             └─────────────────┘
```

The bridge script (`claude-bridge.js`):
1. Receives JSON-RPC messages from Claude Desktop via stdin
2. Adds authentication headers (Bearer token from your configuration)
3. Forwards requests to Rails at `http://localhost:3001/mcp`
4. Returns responses to Claude Desktop via stdout
5. Handles errors and ensures proper JSON-RPC formatting

## Directory Structure

```
your-rails-app/
├── app/
│   └── tools/
│       └── user_manager_tool.rb  # Your generated tool
├── config/
│   └── initializers/
│       └── mcp_on_ruby.rb        # MCP configuration
└── config/routes.rb              # MCP route added automatically

~/mcp-bridge/                     # Or your preferred location
└── claude-bridge.js              # Bridge script
```

## Troubleshooting

**Claude Desktop shows "Connection failed":**
- Ensure Rails server is running on port 3001
- Check that the bridge script path in Claude config is correct

**"Unexpected end of JSON input":**
- Verify authentication token matches exactly in both Rails config (`my-secure-token`) and bridge script (`AUTH_TOKEN`)
- Check Rails server logs for authentication errors

**Tools not appearing in Claude:**
- Restart Claude Desktop after configuration changes
- Verify tools are being auto-registered (check Rails logs)

**Bridge script not executing:**
- Ensure Node.js is installed and accessible
- Make sure the script has execute permissions

## Customizing the Setup

To modify ports or authentication:

1. **Change Rails port:**
   ```bash
   rails server -p 3002  # Use different port
   ```

2. **Update bridge script:**
   Edit `RAILS_PORT` in `claude-bridge.js`

3. **Change authentication token:**
   Update both Rails config (`config.authentication_token`) and `AUTH_TOKEN` in bridge script

## What You Get

Once connected, Claude Desktop can:
- Discover and use any tools you create in `app/tools/`
- Access resources you define in `app/resources/`
- Interact with your Rails application's data and functionality
- Provide a natural language interface to your application's capabilities

This setup provides a secure, production-ready connection between Claude Desktop and your Rails application via MCP on Ruby.