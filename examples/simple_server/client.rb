# frozen_string_literal: true

require "faraday"
require "json"

# Simple MCP client example
class MCPClient
  def initialize(base_url = "http://localhost:3000")
    @base_url = base_url
    @client = Faraday.new(url: @base_url) do |conn|
      conn.request :json
      conn.response :json
      conn.adapter :net_http
    end
  end
  
  def list_engines
    response = @client.get("engines")
    response.body["engines"]
  end
  
  def create_context(messages = [])
    response = @client.post("contexts", { messages: messages })
    response.body
  end
  
  def add_message(context_id, role, content)
    response = @client.post("messages", {
      context_id: context_id,
      role: role,
      content: content
    })
    response.body
  end
  
  def generate(context_id, engine_id, options = {})
    params = {
      context_id: context_id,
      engine_id: engine_id
    }.merge(options)
    
    response = @client.post("generate", params)
    response.body
  end
end

# Usage example
if __FILE__ == $PROGRAM_NAME
  client = MCPClient.new
  
  # List available engines
  engines = client.list_engines
  puts "Available engines:"
  engines.each do |engine|
    puts "- #{engine["id"]}"
  end
  
  # Create a context
  context = client.create_context([
    { role: "system", content: "You are a helpful assistant." }
  ])
  context_id = context["id"]
  puts "\nCreated context: #{context_id}"
  
  # Add a user message
  client.add_message(context_id, "user", "Hello, what can you help me with today?")
  puts "Added user message"
  
  # Generate a response
  response = client.generate(context_id, "openai/gpt-3.5-turbo")
  puts "\nAssistant response:"
  puts response["content"]
end