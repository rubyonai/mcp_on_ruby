# frozen_string_literal: true

# Base class for all MCP resources in this application
class ApplicationResource < McpOnRuby::Resource
  # Common functionality for all resources can be added here
  
  # Example: Add common authorization logic
  # def authorize(context)
  #   # Check if user is authenticated
  #   context[:authenticated] == true
  # end
  
  # Example: Add caching for all resource reads
  # def read(params = {}, context = {})
  #   cache_key = "mcp:resource:#{uri}:#{params.to_json}"
  #   Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
  #     super
  #   end
  # end
end