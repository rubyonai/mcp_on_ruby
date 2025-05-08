# Testing MCP on Ruby

This document describes how to run tests and troubleshoot common issues with the MCP Ruby implementation.

## Running Tests

To run all tests:

```sh
bundle exec rspec
```

To run a specific test file:

```sh
bundle exec rspec spec/path/to/file_spec.rb
```

## Test Structure

- Unit tests are in `spec/unit/`
- Integration tests are in `spec/integration/`

## Common Issues and Solutions

### Module Naming and Resolution

The MCP implementation has a specific module structure with nested modules. This can cause issues in tests if the module resolution is not handled correctly.

The main module structure is:

```
MCP
├── Client
│   ├── Client
│   ├── Auth
│   ├── Retry
│   ├── Streaming
│   └── ...
├── Server
│   ├── Server
│   ├── Tools
│   ├── Resources
│   ├── Prompts
│   ├── Roots
│   └── ...
└── Protocol
    ├── JsonRPC
    ├── Connection
    ├── Transport
    └── ...
```

#### Solution

1. Use explicit module paths in tests
2. Prepend module references with the global namespace (e.g., `::MCP::Client`)
3. Use the module aliases defined in `lib/ruby_mcp/module_aliases.rb`

Example:

```ruby
# Instead of
RSpec.describe MCP::Client::Client do
  # ...
end

# Use
RSpec.describe 'Client' do
  let(:client_class) { MCP::Client::Client }
  # ...
end
```

### Mock Objects for Testing

When testing components that rely on external dependencies (like HTTP connections), use mock objects to isolate the component being tested.

```ruby
# Example mock for a transport
let(:transport) { 
  double(
    connect: double,
    connected?: true,
    disconnect: nil,
    on_event: nil,
    send_message: {}
  )
}
```

### Fixed Test Files

The following test files have been fixed to use the correct module references:

- `spec/unit/client/client_fixed_spec.rb`
- `spec/unit/client/client_test_spec.rb`
- `spec/unit/protocol/json_rpc_fixed_spec.rb`

Use these as templates for fixing other test files.

## Test Helpers

The `MCPTestHelpers` module in `spec/support/test_helpers.rb` provides common mock objects for testing.

```ruby
include MCPTestHelpers

let(:transport) { mock_transport }
let(:connection) { mock_connection }
```