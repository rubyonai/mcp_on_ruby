# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - UNRELEASED

### Added
- Complete rewrite to implement Model Context Protocol specification
- JSON-RPC 2.0 bidirectional communication
- Server implementation with tools, resources, prompts, and roots
- Client implementation for connecting to MCP servers
- HTTP and STDIO transport options
- Comprehensive test suite
- Detailed documentation

## [0.2.0] - 2024-07-24

### Added
- OAuth 2.1 authentication for secure remote connections
- Permission-based access control for MCP methods
- JWT token validation and management
- Automatic token refresh mechanism
- HTTP transport authentication integration
- Middleware architecture for server authentication
- Authentication examples and documentation

## [0.1.0] - 2024-06-15

### Added
- Initial implementation of core MCP protocol
- JSON-RPC 2.0 message format
- HTTP and STDIO transports
- Basic server and client functionality
- Tool definition and execution
- Resource management
- Prompt handling
- Root filesystem access