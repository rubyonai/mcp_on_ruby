# frozen_string_literal: true

module MCP
  module Server
    module Roots
      # Manages roots for the MCP server
      class Manager
        def initialize
          @roots = {}
          @logger = MCP.logger
        end
        
        # Register a root
        # @param root [Root] The root to register
        # @param key [String] Optional key to register the root under
        # @raise [MCP::Errors::RootError] If a root with the same key already exists
        def register(root, key = nil)
          key ||= root.name
          
          if @roots.key?(key)
            raise MCP::Errors::RootError, "Root with key '#{key}' already exists"
          end
          
          @roots[key] = root
          @logger.debug("Registered root: #{key}")
        end
        
        # Unregister a root
        # @param key [String] The key of the root to unregister
        # @return [Root, nil] The unregistered root, or nil if not found
        def unregister(key)
          root = @roots.delete(key)
          @logger.debug("Unregistered root: #{key}") if root
          root
        end
        
        # Get a root by key
        # @param key [String] The key of the root to get
        # @return [Root, nil] The root, or nil if not found
        def get(key)
          @roots[key]
        end
        
        # Check if a root exists
        # @param key [String] The key of the root to check
        # @return [Boolean] true if the root exists
        def exists?(key)
          @roots.key?(key)
        end
        
        # Get all registered roots
        # @return [Hash<String, Root>] All registered roots
        def all
          @roots
        end
        
        # List files in a root
        # @param key [String] The key of the root to list
        # @param path [String] The path to list
        # @return [Array<Hash>] The list of files
        # @raise [MCP::Errors::RootError] If the root does not exist
        def list(key, path = '')
          root = get(key)
          
          if root.nil?
            raise MCP::Errors::RootError, "Root not found: #{key}"
          end
          
          begin
            root.list(path)
          rescue => e
            @logger.error("Error listing root '#{key}': #{e.message}")
            raise MCP::Errors::RootError, "Error listing root '#{key}': #{e.message}"
          end
        end
        
        # Read a file from a root
        # @param key [String] The key of the root to read from
        # @param path [String] The path to read
        # @return [String] The file content
        # @raise [MCP::Errors::RootError] If the root does not exist
        def read(key, path)
          root = get(key)
          
          if root.nil?
            raise MCP::Errors::RootError, "Root not found: #{key}"
          end
          
          begin
            root.read(path)
          rescue => e
            @logger.error("Error reading from root '#{key}': #{e.message}")
            raise MCP::Errors::RootError, "Error reading from root '#{key}': #{e.message}"
          end
        end
        
        # Write to a file in a root
        # @param key [String] The key of the root to write to
        # @param path [String] The path to write to
        # @param content [String] The content to write
        # @return [Boolean] true if successful
        # @raise [MCP::Errors::RootError] If the root does not exist or writes are not allowed
        def write(key, path, content)
          root = get(key)
          
          if root.nil?
            raise MCP::Errors::RootError, "Root not found: #{key}"
          end
          
          begin
            root.write(path, content)
          rescue => e
            @logger.error("Error writing to root '#{key}': #{e.message}")
            raise MCP::Errors::RootError, "Error writing to root '#{key}': #{e.message}"
          end
        end
        
        # Create a root
        # @param name [String] The root name
        # @param path [String] The filesystem path
        # @param description [String] Optional description for the root
        # @param allow_writes [Boolean] Whether to allow writes to the root
        # @return [Root] The created root
        def create_root(name, path, description: nil, allow_writes: false)
          Root.new(name, path, description: description, allow_writes: allow_writes)
        end
        
        # Register root handlers on the server
        # @param server [MCP::Server::Server] The server to register the handlers on
        def register_handlers(server)
          # Register roots/list method handler
          server.on_method('roots/list') do |_params|
            handle_list
          end
          
          # Register roots/read method handler
          server.on_method('roots/read') do |params|
            handle_read(params)
          end
          
          # Register roots/write method handler
          server.on_method('roots/write') do |params|
            handle_write(params)
          end
        end
        
        private
        
        # Handle roots/list method
        # @return [Hash] The response
        def handle_list
          {
            roots: @roots.values.map(&:to_mcp_root)
          }
        end
        
        # Handle roots/read method
        # @param params [Hash] The method parameters
        # @return [Hash] The response
        def handle_read(params)
          begin
            root_name = params[:root]
            path = params[:path] || ''
            
            # Read the file
            content = read(root_name, path)
            
            # Try to determine MIME type
            mime_type = case File.extname(path).downcase
                        when '.txt'
                          'text/plain'
                        when '.html', '.htm'
                          'text/html'
                        when '.json'
                          'application/json'
                        when '.md'
                          'text/markdown'
                        when '.csv'
                          'text/csv'
                        else
                          'application/octet-stream'
                        end
            
            {
              contents: [
                {
                  content: content,
                  mime_type: mime_type
                }
              ]
            }
          rescue MCP::Errors::RootError => e
            raise e
          rescue => e
            @logger.error("Error reading root #{root_name}: #{e.message}")
            raise MCP::Errors::RootError, "Error reading root: #{e.message}"
          end
        end
        
        # Handle roots/write method
        # @param params [Hash] The method parameters
        # @return [Hash] The response
        def handle_write(params)
          begin
            root_name = params[:root]
            path = params[:path]
            content = params[:content]
            
            # Write the file
            if write(root_name, path, content)
              { success: true }
            else
              { success: false }
            end
          rescue MCP::Errors::RootError => e
            raise e
          rescue => e
            @logger.error("Error writing to root #{root_name}: #{e.message}")
            raise MCP::Errors::RootError, "Error writing to root: #{e.message}"
          end
        end
      end
    end
  end
end