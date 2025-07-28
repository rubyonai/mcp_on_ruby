# frozen_string_literal: true

# Base class for all MCP tools in this application
class ApplicationTool < McpOnRuby::Tool
  # Common functionality for all tools can be added here
  
  # Example: Add common authorization logic
  # def authorize(context)
  #   # Check if user is authenticated
  #   context[:authenticated] == true
  # end
  
  # Example: Add logging for all tool executions
  # def call(arguments = {}, context = {})
  #   Rails.logger.info("Tool #{name} called with: #{arguments.inspect}")
  #   super
  # end
end