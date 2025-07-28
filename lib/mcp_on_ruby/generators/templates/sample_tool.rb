# frozen_string_literal: true

# Sample tool demonstrating MCP tool creation
class SampleTool < ApplicationTool
  def initialize
    super(
      name: 'sample_tool',
      description: 'A sample tool that demonstrates basic functionality',
      input_schema: {
        type: 'object',
        properties: {
          message: {
            type: 'string',
            description: 'Message to process'
          },
          count: {
            type: 'integer',
            description: 'Number of times to repeat',
            minimum: 1,
            maximum: 10,
            default: 1
          }
        },
        required: ['message']
      },
      metadata: {
        category: 'sample',
        version: '1.0.0'
      },
      tags: ['sample', 'demo']
    )
  end

  protected

  def execute(arguments, context)
    message = arguments['message']
    count = arguments['count'] || 1
    
    # Example: Access Rails models or services
    # user_count = User.count
    
    {
      success: true,
      result: message * count,
      processed_at: Time.current.iso8601,
      context_info: {
        remote_ip: context[:remote_ip],
        user_agent: context[:user_agent]
      }
    }
  end

  # Optional: Add authorization logic
  # def authorize(context)
  #   # Example: Only allow authenticated users
  #   context[:authenticated] == true
  # end
end