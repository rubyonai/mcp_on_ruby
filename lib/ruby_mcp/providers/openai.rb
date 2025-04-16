# frozen_string_literal: true

module RubyMCP
    module Providers
      class Openai < Base
        def list_engines
          response = create_client.get("models")
          
          unless response.success?
            raise RubyMCP::Errors::ProviderError, "Failed to list OpenAI models: #{response.body["error"]&.dig("message") || response.status}"
          end
          
          models = response.body["data"]
          
          models.map do |model_data|
            if model_data["id"].start_with?("gpt")
              capabilities = ["text-generation"]
              capabilities << "streaming" if model_data["id"].start_with?("gpt-3.5", "gpt-4")
              capabilities << "tool-calls" if model_data["id"].start_with?("gpt-3.5", "gpt-4")
              
              RubyMCP::Models::Engine.new(
                id: "openai/#{model_data["id"]}",
                provider: "openai",
                model: model_data["id"],
                capabilities: capabilities
              )
            end
          end.compact
        end
        
        def generate(context, options = {})
          messages = format_messages(context)
          
          payload = {
            model: options[:model],
            messages: messages,
            max_tokens: options[:max_tokens],
            temperature: options[:temperature],
            top_p: options[:top_p],
            frequency_penalty: options[:frequency_penalty],
            presence_penalty: options[:presence_penalty],
            stop: options[:stop]
          }.compact
          
          if options[:tools]
            payload[:tools] = options[:tools]
            payload[:tool_choice] = options[:tool_choice] || "auto"
          end
          
          response = create_client.post("chat/completions", payload)
          
          unless response.success?
            raise RubyMCP::Errors::ProviderError, "OpenAI generation failed: #{response.body["error"]&.dig("message") || response.status}"
          end
          
          choice = response.body["choices"]&.first
          content = choice&.dig("message", "content")
          
          # Handle tool calls
          tool_calls = nil
          if choice&.dig("message", "tool_calls")
            tool_calls = choice["message"]["tool_calls"].map do |tc|
              {
                id: tc["id"],
                type: "function",
                function: {
                  name: tc["function"]["name"],
                  arguments: tc["function"]["arguments"]
                }
              }
            end
          end
          
          result = {
            provider: "openai",
            model: options[:model],
            created_at: Time.now.utc.iso8601
          }
          
          if tool_calls
            result[:tool_calls] = tool_calls
          else
            result[:content] = content
          end
          
          result
        end
        
        def generate_stream(context, options = {}, &block)
          messages = format_messages(context)
          
          payload = {
            model: options[:model],
            messages: messages,
            max_tokens: options[:max_tokens],
            temperature: options[:temperature],
            top_p: options[:top_p],
            frequency_penalty: options[:frequency_penalty],
            presence_penalty: options[:presence_penalty],
            stop: options[:stop],
            stream: true
          }.compact
          
          if options[:tools]
            payload[:tools] = options[:tools]
            payload[:tool_choice] = options[:tool_choice] || "auto"
          end
          
          conn = create_client
          
          # Update the client to handle streaming
          conn.options.timeout = 120  # Longer timeout for streaming
          
          generation_id = SecureRandom.uuid
          content_buffer = ""
          current_tool_calls = []
          
          # Initial event
          yield({
            id: generation_id,
            event: "generation.start",
            created_at: Time.now.utc.iso8601
          })
          
          begin
            conn.post("chat/completions") do |req|
              req.body = payload.to_json
              req.options.on_data = Proc.new do |chunk, size, total|
                next if chunk.strip.empty?
                
                # Process each SSE event
                chunk.split("data: ").each do |data|
                  next if data.strip.empty?
                  
                  # Skip "[DONE]" marker
                  next if data.strip == "[DONE]"
                  
                  begin
                    json = JSON.parse(data.strip)
                    delta = json.dig("choices", 0, "delta")
                    
                    if delta&.key?("content") && delta["content"]
                      content_buffer += delta["content"]
                      
                      # Send content update
                      yield({
                        id: generation_id,
                        event: "generation.content",
                        created_at: Time.now.utc.iso8601,
                        content: delta["content"]
                      })
                    end
                    
                    # Handle tool call updates
                    if delta&.key?("tool_calls")
                      delta["tool_calls"].each do |tc|
                        tc_id = tc["index"]
                        
                        # Initialize tool call if it's new
                        current_tool_calls[tc_id] ||= {
                          "id" => SecureRandom.uuid,
                          "type" => "function",
                          "function" => {
                            "name" => "",
                            "arguments" => ""
                          }
                        }
                        
                        # Update function name
                        if tc.dig("function", "name")
                          current_tool_calls[tc_id]["function"]["name"] += tc["function"]["name"]
                        end
                        
                        # Update arguments
                        if tc.dig("function", "arguments")
                          current_tool_calls[tc_id]["function"]["arguments"] += tc["function"]["arguments"]
                        end
                        
                        # Send tool call update
                        yield({
                          id: generation_id,
                          event: "generation.tool_call",
                          created_at: Time.now.utc.iso8601,
                          tool_calls: current_tool_calls
                        })
                      end
                    end
                  rescue JSON::ParserError => e
                    # Skip invalid JSON
                    RubyMCP.logger.warn "Invalid JSON in OpenAI stream: #{e.message}"
                  end
                end
              end
            end
          rescue Faraday::Error => e
            raise RubyMCP::Errors::ProviderError, "OpenAI streaming failed: #{e.message}"
          end
          
          # Final event
          if current_tool_calls.any?
            # Final tool calls event
            yield({
              id: generation_id,
              event: "generation.complete",
              created_at: Time.now.utc.iso8601,
              tool_calls: current_tool_calls
            })
          else
            # Final content event
            yield({
              id: generation_id,
              event: "generation.complete",
              created_at: Time.now.utc.iso8601,
              content: content_buffer
            })
          end
        end
        
        def abort_generation(generation_id)
          # OpenAI doesn't support aborting generations yet
          raise RubyMCP::Errors::ProviderError, "OpenAI doesn't support aborting generations"
        end
        
        protected
        
        def default_api_base
          "https://api.openai.com/v1"
        end
        
        private
        
        def format_messages(context)
          context.messages.map do |msg|
            # Convert to OpenAI's message format
            message = { "role" => msg.role, "content" => msg.content }
            
            # Handle structured content
            if msg.content_type == "array"
              content_parts = []
              
              msg.content.each do |part|
                if part.is_a?(String)
                  content_parts << { "type" => "text", "text" => part }
                elsif part.is_a?(Hash)
                  if part[:type] == "text"
                    content_parts << { "type" => "text", "text" => part[:text] }
                  elsif part[:type] == "content_pointer"
                    # We don't have file IDs for OpenAI here
                    # In a real implementation, we would upload the file to OpenAI
                    content_parts << { "type" => "text", "text" => "[Content reference: #{part[:content_id]}]" }
                  end
                end
              end
              
              message["content"] = content_parts
            end
            
            message
          end
        end
      end
    end
  end