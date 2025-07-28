# frozen_string_literal: true

# <%= resource_description %>
class <%= resource_class_name %> < ApplicationResource
  def initialize
    super(
      uri: '<%= resource_uri %>',
      name: '<%= name.humanize %>',
      description: '<%= resource_description %>',
      mime_type: '<%= resource_mime_type %>',
      metadata: {
        category: 'custom',
        version: '1.0.0'
      },
      tags: ['<%= resource_name %>']
    )
  end

  protected

  def fetch_content(params, context)
    <% if is_template? -%>
    # This is a templated resource with parameters: <%= template_params.join(', ') %>
    # Access parameters via params hash:
    <% template_params.each do |param| -%>
    # <%= param %> = params['<%= param %>']
    <% end -%>
    <% end -%>
    
    # Implement your resource content fetching logic here
    # Return data that will be serialized according to mime_type
    
    {
      resource: '<%= resource_name %>',
      <% if is_template? -%>
      parameters: params,
      <% end -%>
      data: {
        # Your resource data here
      },
      generated_at: Time.current.iso8601
    }
  end

  # Optional: Add authorization logic
  # def authorize(context)
  #   # Return true/false based on context (user, permissions, etc.)
  #   true
  # end
end