# frozen_string_literal: true

# Sample resource demonstrating MCP resource creation
class SampleResource < ApplicationResource
  def initialize
    super(
      uri: 'sample_data',
      name: 'Sample Data',
      description: 'A sample resource that provides application statistics',
      mime_type: 'application/json',
      metadata: {
        category: 'sample',
        version: '1.0.0'
      },
      tags: ['sample', 'stats']
    )
  end

  protected

  def fetch_content(params, context)
    # Example: Fetch data from Rails models
    {
      application: {
        name: Rails.application.class.module_parent_name,
        environment: Rails.env,
        version: '1.0.0'
      },
      statistics: {
        # users_count: User.count,
        # posts_count: Post.count,
        uptime: uptime_info
      },
      timestamp: Time.current.iso8601,
      request_info: {
        remote_ip: context[:remote_ip],
        user_agent: context[:user_agent]
      }
    }
  end

  # Optional: Add authorization logic
  # def authorize(context)
  #   # Example: Only allow authenticated users to read this resource
  #   context[:authenticated] == true
  # end

  private

  def uptime_info
    load_avg = `uptime`.strip rescue 'unavailable'
    {
      server_uptime: load_avg,
      rails_uptime: Time.current - Rails.application.config.time_zone.parse('2024-01-01')
    }
  end
end