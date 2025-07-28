# Testing Guide

## RSpec Integration

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

## Integration Testing

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