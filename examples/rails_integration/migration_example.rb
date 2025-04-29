# frozen_string_literal: true

# Example Rails migration for RubyMCP ActiveRecord storage
# Create this file in db/migrate/YYYYMMDDHHMMSS_create_mcp_tables.rb

class CreateMcpTables < ActiveRecord::Migration[6.1]
  def change
    # Use environment-specific prefixes to isolate tables
    prefix = "mcp_#{Rails.env}_"

    create_table "#{prefix}contexts" do |t|
      # External ID is the MCP context ID (e.g., "ctx_123abc")
      t.string :external_id, null: false
      # Metadata stored as JSON
      t.text :metadata, default: '{}'
      # Standard timestamps
      t.timestamps

      # Indexes for performance
      t.index :external_id, unique: true
      t.index :updated_at
    end

    create_table "#{prefix}messages" do |t|
      # Reference to context table with cascading delete
      t.references :context, null: false,
                             foreign_key: { to_table: "#{prefix}contexts", on_delete: :cascade }
      # External ID is the MCP message ID (e.g., "msg_123abc")
      t.string :external_id, null: false
      # Message role (user, assistant, system, tool)
      t.string :role, null: false
      # Message content
      t.text :content, null: false
      # Message metadata stored as JSON
      t.text :metadata, default: '{}'
      # Standard timestamps
      t.timestamps

      # Compound index for looking up messages by context and external ID
      t.index %i[context_id external_id], unique: true
    end

    create_table "#{prefix}contents" do |t|
      # Reference to context table with cascading delete
      t.references :context, null: false,
                             foreign_key: { to_table: "#{prefix}contexts", on_delete: :cascade }
      # External ID is the MCP content ID (e.g., "cnt_123abc")
      t.string :external_id, null: false
      # Binary data for files, etc.
      t.binary :data_binary, limit: 10.megabytes
      # JSON data for structured content
      t.text :data_json
      # Type of content ('binary' or 'json')
      t.string :content_type
      # Standard timestamps
      t.timestamps

      # Compound index for looking up content by context and external ID
      t.index %i[context_id external_id], unique: true
    end
  end

  # Optional: Method to revert the migration
  def down
    prefix = "mcp_#{Rails.env}_"

    drop_table "#{prefix}contents"
    drop_table "#{prefix}messages"
    drop_table "#{prefix}contexts"
  end
end
