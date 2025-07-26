# frozen_string_literal: true

# <%= tool_description %>
class <%= tool_class_name %> < ApplicationTool
  def initialize
    super(
      name: '<%= tool_name %>',
      description: '<%= tool_description %>',
      <%= input_schema_code %>,
      metadata: {
        category: 'custom',
        version: '1.0.0'
      },
      tags: ['<%= tool_name %>']
    )
  end

  protected

  def execute(arguments, context)
    # Implement your tool logic here
    # Arguments are validated according to input_schema
    # Context contains request information (IP, headers, etc.)
    
    {
      success: true,
      result: "Tool <%= tool_name %> executed successfully",
      arguments: arguments,
      processed_at: Time.current.iso8601
    }
  end

  # Optional: Add authorization logic
  # def authorize(context)
  #   # Return true/false based on context (user, permissions, etc.)
  #   true
  # end
end