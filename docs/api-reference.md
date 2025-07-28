# API Reference

## Server Methods

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

## Tool Class

```ruby
class MyTool < McpOnRuby::Tool
  def initialize(name:, description: '', input_schema: {}, **options)
  def execute(arguments, context) # Override this
  def authorize(context) # Optional override
end
```

## Resource Class

```ruby
class MyResource < McpOnRuby::Resource
  def initialize(uri:, name: nil, description: '', mime_type: 'application/json', **options)
  def fetch_content(params, context) # Override this
  def authorize(context) # Optional override
end
```