# frozen_string_literal: true

module MCP
  module Server
    module Prompts
      # Manages prompts for the MCP server
      class Manager
        def initialize
          @prompts = {}
          @logger = MCP.logger
        end
        
        # Register a prompt
        # @param prompt [Prompt] The prompt to register
        # @param key [String] Optional key to register the prompt under
        # @raise [MCP::Errors::PromptError] If a prompt with the same key already exists
        def register(prompt, key = nil)
          key ||= prompt.name
          
          if @prompts.key?(key)
            raise MCP::Errors::PromptError, "Prompt with key '#{key}' already exists"
          end
          
          @prompts[key] = prompt
          @logger.debug("Registered prompt: #{key}")
        end
        
        # Unregister a prompt
        # @param key [String] The key of the prompt to unregister
        # @return [Prompt, nil] The unregistered prompt, or nil if not found
        def unregister(key)
          prompt = @prompts.delete(key)
          @logger.debug("Unregistered prompt: #{key}") if prompt
          prompt
        end
        
        # Get a prompt by key
        # @param key [String] The key of the prompt to get
        # @return [Prompt, nil] The prompt, or nil if not found
        def get(key)
          @prompts[key]
        end
        
        # Check if a prompt exists
        # @param key [String] The key of the prompt to check
        # @return [Boolean] true if the prompt exists
        def exists?(key)
          @prompts.key?(key)
        end
        
        # Get all registered prompts
        # @return [Hash<String, Prompt>] All registered prompts
        def all
          @prompts
        end
        
        # Render a prompt
        # @param key [String] The key of the prompt to render
        # @param params [Hash] The parameters for the prompt
        # @return [Array<Hash>] The rendered prompt messages
        # @raise [MCP::Errors::PromptError] If the prompt does not exist
        def render(key, params = {})
          prompt = get(key)
          
          if prompt.nil?
            raise MCP::Errors::PromptError, "Prompt not found: #{key}"
          end
          
          begin
            prompt.render(params)
          rescue => e
            @logger.error("Error rendering prompt '#{key}': #{e.message}")
            raise MCP::Errors::PromptError, "Error rendering prompt '#{key}': #{e.message}"
          end
        end
        
        # Create a prompt from a block
        # @param name [String] The prompt name
        # @param description [String] Optional description for the prompt
        # @param parameters [Hash] Optional parameters schema
        # @param tags [Array<String>] Optional tags for the prompt
        # @param &block [Proc] The handler block for prompt rendering
        # @return [Prompt] The created prompt
        def create_prompt(name, description: nil, parameters: nil, tags: [], &block)
          Prompt.new(name, block, parameters: parameters, description: description, tags: tags)
        end
        
        # Register prompt handlers on the server
        # @param server [MCP::Server::Server] The server to register the handlers on
        def register_handlers(server)
          # Register prompts/list method handler
          server.on_method('prompts/list') do |_params|
            handle_list
          end
          
          # Register prompts/get method handler
          server.on_method('prompts/get') do |params|
            handle_get(params)
          end
        end
        
        private
        
        # Handle prompts/list method
        # @return [Hash] The response
        def handle_list
          {
            prompts: @prompts.values.map(&:to_mcp_prompt)
          }
        end
        
        # Handle prompts/get method
        # @param params [Hash] The method parameters
        # @return [Hash] The response
        def handle_get(params)
          begin
            name = params[:name]
            arguments = params[:arguments] || {}
            
            # Render the prompt
            messages = render(name, arguments)
            
            {
              messages: messages
            }
          rescue MCP::Errors::PromptError => e
            raise e
          rescue => e
            @logger.error("Error getting prompt #{name}: #{e.message}")
            raise MCP::Errors::PromptError, "Error getting prompt: #{e.message}"
          end
        end
      end
    end
  end
end