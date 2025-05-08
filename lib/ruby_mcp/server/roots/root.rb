# frozen_string_literal: true

require 'pathname'

module MCP
  module Server
    module Roots
      # MCP root class
      class Root
        attr_reader :name, :description, :path, :allow_writes
        
        # Initialize a root
        # @param name [String] The root name
        # @param path [String] The filesystem path
        # @param description [String] Optional description for the root
        # @param allow_writes [Boolean] Whether to allow writes to the root
        def initialize(name, path, description: nil, allow_writes: false)
          @name = name
          @path = File.expand_path(path)
          @description = description || ""
          @allow_writes = allow_writes
        end
        
        # Convert to an MCP root definition
        # @return [Hash] The MCP root definition
        def to_mcp_root
          {
            name: @name,
            description: @description,
            allowWrites: @allow_writes
          }
        end
        
        # List files in the root
        # @param subpath [String] The subpath to list
        # @return [Array<Hash>] The list of files
        def list(subpath = '')
          full_path = resolve_path(subpath)
          
          entries = Dir.entries(full_path)
            .reject { |e| e == '.' || e == '..' }
            .map do |entry|
              entry_path = File.join(full_path, entry)
              {
                name: entry,
                path: entry_path.sub(@path, ''),
                type: File.directory?(entry_path) ? 'directory' : 'file',
                size: File.size(entry_path),
                modified_at: File.mtime(entry_path).iso8601
              }
            end
          
          entries
        end
        
        # Read a file from the root
        # @param path [String] The path to read
        # @return [String] The file content
        def read(path)
          full_path = resolve_path(path)
          File.read(full_path)
        end
        
        # Write to a file in the root
        # @param path [String] The path to write to
        # @param content [String] The content to write
        # @return [Boolean] true if successful
        # @raise [MCP::Errors::RootError] If writes are not allowed
        def write(path, content)
          unless @allow_writes
            raise MCP::Errors::RootError, "Writes are not allowed to this root"
          end
          
          full_path = resolve_path(path)
          
          # Create parent directories if they don't exist
          dirname = File.dirname(full_path)
          FileUtils.mkdir_p(dirname) unless File.directory?(dirname)
          
          # Write the content
          File.write(full_path, content)
          
          true
        end
        
        private
        
        # Resolve a path relative to the root
        # @param subpath [String] The subpath to resolve
        # @return [String] The full path
        # @raise [MCP::Errors::RootError] If the path is outside the root
        def resolve_path(subpath)
          # Clean the path
          subpath = subpath.to_s.sub(/^\//, '')
          
          # Get the full path
          full_path = File.join(@path, subpath)
          
          # Expand to absolute path
          full_path = File.expand_path(full_path)
          
          # Ensure the path is within the root directory
          unless full_path.start_with?(@path)
            raise MCP::Errors::RootError, "Path is outside the root directory"
          end
          
          full_path
        end
      end
    end
  end
end