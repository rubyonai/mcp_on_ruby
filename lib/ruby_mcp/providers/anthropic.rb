# frozen_string_literal: true

module RubyMCP
    module Providers
      class Anthropic < Base
        MODELS = [
          {
            id: "claude-3-opus-20240229",
            capabilities: ["text-generation", "streaming", "tool-calls"]
          },
          {
            id: "claude-3-sonnet-20240229",
            capabilities: ["text-generation", "streaming", "tool-calls"]
          },
          {
            id: "claude-3-haiku-20240307",
            capabilities: ["text-generation", "streaming", "tool-calls"]
          },
          {
            id: "claude-2.1",
            capabilities: ["text-generation", "streaming"]
          },
          {
            id: "claude-2.0",
            capabilities: ["text-generation", "streaming"]
          },
          {
            id: "claude-instant-1.2",
            capabilities: ["text-generation", "streaming"]
          }
        ].freeze
        
        def list_engines
          # Anthropic doesn't have an endpoint to list models, so we use a static list
          MODELS.map do |model_info|
            RubyMCP::Models::Engine.new(
              id: "anthropic/#{model_info[:id]}",
              provider: "anthropic",
              model: model_info[:id],
              capabilities: model_info[:capabilities]
            )
          end
        end
        
        def generate(context, options = {})
          messages = format_messages(context)
          
          payload = {
            model: options[:model],
            messages: messages,
            max_tokens: options[:max_tokens] || 4096,
            temperature: options[:temperature],
            top_p: options[:top_p],
            stop_sequences: options[:stop]
          }.compact
          
          if options[:tools]
            payload[:tools] = options[:tools]
            payload[:tool_choice] = options[:tool_choice] || "auto"
          end
          
          headers = {
            "Anthropic-Version" => "2023-06-01",
            "Content-Type" => "application/json"
          }
          
          response = create_client.post("messages") do |req|
            req.headers.merge!(headers)
            req.body = payload.to_json
          end
          
          unless response.success?
            raise RubyMCP::Errors::ProviderError, "Anthropic generation failed: #{response.body["error"]&.dig("message") || response.status}"
          end
          
          content = response.body["content"]&.first&.dig("text")
          tool_calls = nil
          
          # Handle tool calls
          if response.body["tool_calls"]
            tool_calls = response.body["tool_calls"].map do |tc|
              {
                id: tc["id"],
                type: "function",
                function: {
                  name: tc["name"],
                  arguments: tc["input"]
                }
              }
            end
          end
          
          result = {
            provider: "anthropic",
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
            max_tokens: options[:max_tokens] || 4096,
            temperature: options[:temperature],
            top_p: options[:top_p],
            stop_sequences: options[:stop],
            stream: true
          }.compact
          
          if options[:tools]
            payload[:tools] = options[:tools]
            payload[:tool_choice] = options[:tool_choice] || "auto"
          end
          
          headers = {
            "Anthropic-Version" => "2023-06-01",
            "Content-Type" => "application/json"
          }
          
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
            conn.post("messages") do |req|
              req.headers.merge!(headers)
              req.body = payload.to_json
              req.options.on_data = Proc.new do |chunk, size, total|
                next if chunk.strip.empty?
                
                # Process each SSE event
                chunk.split("data: ").each do |data|
                  next if data.strip.empty?
                  
                  begin
                    json = JSON.parse(data.strip)
                    
                    if json["type"] == "content_block_delta"
                      delta = json["delta"]["text"]
                      content_buffer += delta
                      
                      # Send content update
                      yield({
                        id: generation_id,
                        event: "generation.content",
                        created_at: Time.now.utc.iso8601,
                        content: delta
                      })
                    elsif json["type"] == "tool_call"
                      tool_call = {
                        "id" => json["id"],
                        "type" => "function",
                        "function" => {
                          "name" => json["name"],
                          "arguments" => json["input"]
                        }
                      }
                      
                      current_tool_calls << tool_call
                      
                      # Send tool call update
                      yield({
                        id: generation_id,
                        event: "generation.tool_call",
                        created_at: Time.now.utc.iso8601,
                        tool_calls: current_tool_calls
                      })
                    elsif json["type"] == "message_stop"
                      # Handled by the final event after the streaming is done
                    end
                  rescue JSON::ParserError => e
                    # Skip invalid JSON
                    RubyMCP.logger.warn "Invalid JSON in Anthropic stream: #{e.message}"
                  end
                end
              end
            end
          rescue Faraday::Error => e
            raise RubyMCP::Errors::ProviderError, "Anthropic streaming failed: #{e.message}"
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
          # Anthropic doesn't support aborting generations yet
          raise RubyMCP::Errors::ProviderError, "Anthropic doesn't support aborting generations"
        end
        
        protected
        
        def default_api_base
          "https://api.anthropic.com/v1"
        end
        
        private
        
        def format_messages(context)
          context.messages.map do |msg|
            # Convert to Anthropic's message format
            if msg.content_type == "array"
              # Handle structured content
              content_parts = []
              
              msg.content.each do |part|
                if part.is_a?(String)
                  content_parts << { "type" => "text", "text" => part }
                elsif part.is_a?(Hash)
                  if part[:type] == "text"
                    content_parts << { "type" => "text", "text" => part[:text] }
                  elsif part[:type] == "content_pointer"
                    # We don't have file IDs for Anthropic here
                    content_parts << { "type" => "text", "text" => "[Content reference: #{part[:content_id]}]" }
                  end
                end
              end
              
              { "role" => msg.role, "content" => content_parts }
            else
              # Simple text content
              { "role" => msg.role, "content" => msg.content }
            end
          end
        end
      end
    end
  end