# Authenticated MCP Server Example

This example demonstrates how to create an MCP server with OAuth 2.1 authentication and permission scopes.

## Components

The example consists of three main components:

1. **OAuth Server** - A simple OAuth 2.1 server implementation for testing purposes
2. **MCP Server** - An MCP server with authentication enabled
3. **MCP Client** - A client that connects to the MCP server with authentication

## Setting Up

You'll need to run each component in a separate terminal.

### 1. Start the OAuth Server

```bash
ruby oauth_server.rb
```

This will start a simple OAuth server on port 3001.

### 2. Start the MCP Server

```bash
ruby server.rb
```

This will start an MCP server on port 3000. The server is configured with OAuth authentication and permission scopes.

### 3. Run the Client

```bash
ruby client.rb
```

The client will:
1. Connect to the MCP server with authentication
2. List available tools
3. Call the "hello" tool

## Understanding the Authentication Flow

In a real application, the OAuth flow would typically involve:

1. The client redirecting the user to the authorization server
2. The user granting permission
3. The authorization server redirecting back to the client with an authorization code
4. The client exchanging the code for an access token
5. The client using the access token to access the API

For simplicity, this example bypasses this flow and creates a token directly. 

## Permission Scopes

The server is configured with the following permission scopes:

- `tools:read` - Required to list tools
- `tools:call` - Required to call tools
- `resources:read` - Required to list resources
- `resources:call` - Required to call resources

The client requests the `tools:read` and `tools:call` scopes, which allows it to list and call tools, but not work with resources.

## How Authentication is Integrated

1. **HTTP Transport** - Adds Authentication headers to requests
2. **Server Middleware** - Validates tokens and checks permissions
3. **Client Authentication** - Manages token lifecycle (acquisition, refresh, etc.)
4. **Permission Manager** - Maps MCP methods to required scopes

This architecture follows the principles of OAuth 2.1 and integrates with the MCP protocol's JSON-RPC 2.0 message format.