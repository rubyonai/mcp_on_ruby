# frozen_string_literal: true

# This example demonstrates how to use ActiveRecord storage with RubyMCP in a Rails application

# Step 1: Add gems to your Gemfile
# gem 'mcp_on_ruby', '~> 0.3.0'
# gem 'activerecord', '~> 6.1'  # Usually already included in Rails
# gem 'sqlite3', '~> 1.4'       # Or your preferred database adapter

###############################################
# Step 2: Create an initializer
# config/initializers/ruby_mcp.rb
###############################################

require 'ruby_mcp'

Rails.application.config.to_prepare do
  RubyMCP.configure do |config|
    # Configure LLM providers
    config.providers = {
      openai: { api_key: ENV['OPENAI_API_KEY'] },
      anthropic: { api_key: ENV['ANTHROPIC_API_KEY'] }
    }

    # Use ActiveRecord storage with Rails database
    config.storage = :active_record
    config.active_record = {
      # Uses Rails database connection automatically
      table_prefix: "mcp_#{Rails.env}_" # Environment-specific prefix
    }

    # Enable authentication in production
    if Rails.env.production?
      config.auth_required = true
      config.jwt_secret = ENV['JWT_SECRET']
    end
  end

  # Log configuration
  Rails.logger.info "Configured RubyMCP with providers: #{RubyMCP.configuration.providers.keys.join(', ')}"
  Rails.logger.info "Using ActiveRecord storage with prefix: #{RubyMCP.configuration.active_record[:table_prefix]}"
end

###############################################
# Step 3: Mount the MCP server in routes.rb
# config/routes.rb
###############################################

Rails.application.routes.draw do
  # Mount RubyMCP at /api/mcp
  mount_mcp_at = '/api/mcp'

  Rails.application.config.middleware.use Rack::Config do |env|
    env['SCRIPT_NAME'] = mount_mcp_at if env['PATH_INFO'].start_with?(mount_mcp_at)
  end

  mount RubyMCP::Server::App.new.rack_app, at: mount_mcp_at

  # Rest of your routes...
end

###############################################
# Step 4: (Optional) Create a migration
# This is only needed if you prefer migration-based setup
# instead of automatic table creation
###############################################

# Run: rails generate migration CreateMcpTables
# Then edit the migration file:

class CreateMcpTables < ActiveRecord::Migration[6.1]
  def change
    prefix = "mcp_#{Rails.env}_"

    create_table "#{prefix}contexts" do |t|
      t.string :external_id, null: false
      t.text :metadata, default: '{}'
      t.timestamps

      t.index :external_id, unique: true
      t.index :updated_at
    end

    create_table "#{prefix}messages" do |t|
      t.references :context, null: false, foreign_key: { to_table: "#{prefix}contexts", on_delete: :cascade }
      t.string :external_id, null: false
      t.string :role, null: false
      t.text :content, null: false
      t.text :metadata, default: '{}'
      t.timestamps

      t.index %i[context_id external_id], unique: true
    end

    create_table "#{prefix}contents" do |t|
      t.references :context, null: false, foreign_key: { to_table: "#{prefix}contexts", on_delete: :cascade }
      t.string :external_id, null: false
      t.binary :data_binary
      t.text :data_json
      t.string :content_type
      t.timestamps

      t.index %i[context_id external_id], unique: true
    end
  end
end

###############################################
# Step 5: Using RubyMCP with ActiveRecord in your application
###############################################

# app/controllers/conversations_controller.rb
class ConversationsController < ApplicationController
  def create
    # Create a new MCP context
    client = RubyMCP.client

    # Create a context with a system message
    context = client.create_context(
      [{ role: 'system', content: 'You are a helpful assistant.' }],
      { user_id: current_user.id } # Store metadata
    )

    # Store the context ID in your database
    conversation = current_user.conversations.create(
      title: 'New Conversation',
      mcp_context_id: context.id
    )

    redirect_to conversation_path(conversation)
  end

  def show
    @conversation = current_user.conversations.find(params[:id])

    # Get the MCP context
    client = RubyMCP.client
    @context = client.get_context(@conversation.mcp_context_id)

    # Render the conversation UI
  end

  def message
    @conversation = current_user.conversations.find(params[:id])

    # Add user message to context
    client = RubyMCP.client
    client.add_message(
      @conversation.mcp_context_id,
      'user',
      params[:content]
    )

    # Generate AI response
    response = client.generate(
      @conversation.mcp_context_id,
      'openai/gpt-4',
      temperature: 0.7
    )

    # Response is automatically added to the context

    # Return the response
    render json: { content: response[:content] }
  end
end
