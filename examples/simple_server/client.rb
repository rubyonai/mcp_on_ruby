#!/usr/bin/env ruby
# frozen_string_literal: true

require "faraday"
require "json"
require "base64"
require "io/console"

# Terminal styling helpers
module Term
  def self.header(text)
    puts "\n\e[1;36m==== #{text} ====\e[0m"
  end
  
  def self.subheader(text)
    puts "\e[1;34m## #{text}\e[0m"
  end
  
  def self.info(text)
    puts "\e[0;32m#{text}\e[0m"
  end
  
  def self.data(text)
    puts "\e[0;33m#{text}\e[0m"
  end
  
  def self.request(text)
    puts "\e[0;35m⟶ #{text}\e[0m"
  end
  
  def self.response(text)
    puts "\e[0;36m⟵ #{text}\e[0m"
  end
  
  def self.divider
    puts "\e[0;90m" + "-" * 80 + "\e[0m"
  end
  
  def self.wait_for_key
    puts "\e[0;90mPress any key to continue...\e[0m"
    STDIN.getch
  end
end

# Comprehensive MCP client with educational features
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
    Term.request("GET /engines")
    response = @client.get("engines")
    Term.response("Status: #{response.status}")
    
    if response.success?
      response.body["engines"]
    else
      Term.info("Error: #{response.body["error"] || "Unknown error"}")
      []
    end
  end
  
  def create_context(messages = [])
    payload = { messages: messages }
    Term.request("POST /contexts")
    Term.data(JSON.pretty_generate(payload))
    
    response = @client.post("contexts", payload)
    Term.response("Status: #{response.status}")
    
    if response.success?
      response.body
    else
      Term.info("Error: #{response.body["error"] || "Unknown error"}")
      nil
    end
  end
  
  def list_contexts
    Term.request("GET /contexts")
    response = @client.get("contexts")
    Term.response("Status: #{response.status}")
    
    if response.success?
      response.body["contexts"] || []
    else
      Term.info("Error: #{response.body["error"] || "Unknown error"}")
      []
    end
  end
  
  def get_context(context_id)
    Term.request("GET /contexts/#{context_id}")
    response = @client.get("contexts/#{context_id}")
    Term.response("Status: #{response.status}")
    
    if response.success?
      response.body
    else
      Term.info("Error: #{response.body["error"] || "Unknown error"}")
      nil
    end
  end
  
  def delete_context(context_id)
    Term.request("DELETE /contexts/#{context_id}")
    response = @client.delete("contexts/#{context_id}")
    Term.response("Status: #{response.status}")
    
    if response.success?
      response.body
    else
      Term.info("Error: #{response.body["error"] || "Unknown error"}")
      nil
    end
  end
  
  def add_message(context_id, role, content)
    payload = { context_id: context_id, role: role, content: content }
    Term.request("POST /messages")
    Term.data(JSON.pretty_generate(payload))
    
    response = @client.post("messages", payload)
    Term.response("Status: #{response.status}")
    
    if response.success?
      response.body
    else
      Term.info("Error: #{response.body["error"] || "Unknown error"}")
      nil
    end
  end
  
  def generate(context_id, engine_id, options = {})
    params = { context_id: context_id, engine_id: engine_id }.merge(options)
    Term.request("POST /generate")
    Term.data(JSON.pretty_generate(params))
    
    response = @client.post("generate", params)
    Term.response("Status: #{response.status}")
    
    if response.success?
      response.body
    else
      Term.info("Error: #{response.body["error"] || "Unknown error"}")
      nil
    end
  end
  
  def generate_stream(context_id, engine_id, options = {})
    params = { context_id: context_id, engine_id: engine_id }.merge(options)
    Term.request("POST /generate/stream")
    Term.data(JSON.pretty_generate(params))
    
    content_buffer = ""
    @client.post("generate/stream") do |req|
      req.headers["Content-Type"] = "application/json"
      req.body = params.to_json
      
      req.options.on_data = Proc.new do |chunk, size, total|
        chunk.split("data: ").each do |event_data|
          next if event_data.strip.empty? || event_data.strip == "[DONE]"
          
          begin
            event = JSON.parse(event_data)
            if event["event"] == "generation.content" && event["content"]
              print event["content"]
              content_buffer += event["content"]
            end
          rescue JSON::ParserError
            # Skip invalid JSON
          end
        end
      end
    end
    
    puts # Add newline after streaming
    content_buffer
  end
  
  def upload_content(context_id, file_path)
    file_data = Base64.strict_encode64(File.read(file_path))
    filename = File.basename(file_path)
    content_type = guess_content_type(filename)
    
    payload = {
      context_id: context_id,
      type: "file",
      filename: filename,
      content_type: content_type,
      file_data: file_data
    }
    
    Term.request("POST /content")
    Term.data("Uploading: #{filename} (#{content_type})")
    
    response = @client.post("content", payload)
    Term.response("Status: #{response.status}")
    
    if response.success?
      response.body
    else
      Term.info("Error: #{response.body["error"] || "Unknown error"}")
      nil
    end
  end
  
  def get_content(context_id, content_id)
    Term.request("GET /content/#{context_id}/#{content_id}")
    response = @client.get("content/#{context_id}/#{content_id}")
    Term.response("Status: #{response.status}")
    
    if response.success?
      response.body
    else
      Term.info("Error: #{response.body["error"] || "Unknown error"}")
      nil
    end
  end
  
  private
  
  def guess_content_type(filename)
    extension = File.extname(filename).downcase
    case extension
    when ".txt" then "text/plain"
    when ".pdf" then "application/pdf"
    when ".json" then "application/json"
    when ".csv" then "text/csv"
    when ".jpg", ".jpeg" then "image/jpeg"
    when ".png" then "image/png"
    else "application/octet-stream"
    end
  end
end

# Interactive Demo
if __FILE__ == $PROGRAM_NAME
  Term.header("RubyMCP Interactive Demo")
  Term.info("This demo walks through the Model Context Protocol API implemented by RubyMCP")
  Term.info("Each step will show the request, data, and response to help understand the protocol")
  
  client = MCPClient.new
  
  # Step 1: List Engines
  Term.header("Step 1: Engines Endpoint")
  Term.info("The /engines endpoint lists available language models from configured providers")
  Term.divider
  
  engines = client.list_engines
  puts "\nAvailable engines:"
  engines.each do |engine|
    puts "- #{engine["id"]}"
  end
  
  Term.divider
  Term.info("These engines can be used with the 'generate' endpoint to create responses")
  Term.wait_for_key
  
  # Step 2: Create Context
  Term.header("Step 2: Creating a Context")
  Term.info("Contexts are the core concept in MCP - they store conversation history")
  Term.info("The /contexts endpoint lets you create a new conversation space")
  Term.divider
  
  context = client.create_context([
    { role: "system", content: "You are a helpful assistant that provides concise responses." }
  ])
  
  if context
    context_id = context["id"]
    puts "\nCreated context with ID: #{context_id}"
    puts "System message added: #{context["messages"][0]["content"]}"
  else
    exit 1
  end
  
  Term.divider
  Term.info("The context ID is used in all subsequent requests to maintain conversation state")
  Term.wait_for_key
  
  # Step 3: Add a Message
  Term.header("Step 3: Adding a Message")
  Term.info("The /messages endpoint lets you add messages to an existing context")
  Term.info("Messages include role (user/assistant/system/tool) and content")
  Term.divider
  
  message = client.add_message(context_id, "user", "What is the Model Context Protocol?")
  
  if message
    puts "\nAdded user message: #{message["content"]}"
  end
  
  Term.divider
  Term.info("Messages are added to the context and maintained in sequence")
  Term.wait_for_key
  
  # Step 4: Generate a Response
  Term.header("Step 4: Generating a Response")
  Term.info("The /generate endpoint sends the context to a language model and gets a response")
  Term.info("You specify which engine to use and optional parameters like temperature")
  Term.divider
  
  response = client.generate(context_id, "openai/gpt-3.5-turbo", { temperature: 0.7 })
  
  if response && response["content"]
    puts "\nAssistant response:"
    puts response["content"]
  end
  
  Term.divider
  Term.info("The response is automatically added to the context for continuation")
  Term.wait_for_key
  
  # Step 5: Continue the Conversation
  Term.header("Step 5: Continuing the Conversation")
  Term.info("MCP maintains conversation history, allowing for multi-turn interactions")
  Term.divider
  
  followup = client.add_message(context_id, "user", "How is MCP different from direct API calls?")
  
  if followup
    puts "\nAdded follow-up question: #{followup["content"]}"
  end
  
  response = client.generate(context_id, "openai/gpt-3.5-turbo")
  
  if response && response["content"]
    puts "\nAssistant response:"
    puts response["content"]
  end
  
  Term.divider
  Term.info("The context now contains the entire conversation history")
  Term.wait_for_key
  
  # Step 6: Streaming Generation
  Term.header("Step 6: Streaming Responses")
  Term.info("The /generate/stream endpoint provides token-by-token streaming responses")
  Term.info("This allows for more responsive UI experiences")
  Term.divider
  
  client.add_message(context_id, "user", "Explain the benefits of standardizing LLM interactions")
  
  puts "\nStreaming response (token by token):"
  client.generate_stream(context_id, "openai/gpt-3.5-turbo")
  
  Term.divider
  Term.info("Streaming lets users see responses as they're generated, reducing perceived latency")
  Term.wait_for_key
  
  # Step 7: Retrieving the Context
  Term.header("Step 7: Retrieving Context History")
  Term.info("The GET /contexts/:id endpoint lets you retrieve the full conversation history")
  Term.divider
  
  full_context = client.get_context(context_id)
  
  if full_context
    messages_count = full_context["messages"].size
    puts "\nContext #{context_id} contains #{messages_count} messages:"
    
    full_context["messages"].each_with_index do |msg, i|
      puts "#{i+1}. #{msg["role"]}: #{msg["content"].to_s[0..50]}..."
    end
  end
  
  Term.divider
  Term.info("Retrieving contexts lets you inspect conversation state or resume conversations")
  Term.wait_for_key
  
  # Conclusion
  Term.header("Demo Complete")
  Term.info("You've now seen the core MCP endpoints in action:")
  puts "✓ Engine listing (/engines)"
  puts "✓ Context creation and management (/contexts)"
  puts "✓ Message handling (/messages)"
  puts "✓ Response generation (/generate)"
  puts "✓ Streaming responses (/generate/stream)"
  
  Term.divider
  puts "MCP provides a standardized way to interact with language models, allowing:"
  puts "- Consistent API across different LLM providers"
  puts "- Automated context management"
  puts "- Structured conversation handling"
  puts "- Tool integration capabilities"
  
  Term.divider
  Term.info("RubyMCP implements this protocol for Ruby applications, making it easy to")
  Term.info("integrate LLMs into your Ruby and Rails projects with a clean, consistent API.")
end