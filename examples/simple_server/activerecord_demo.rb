#!/usr/bin/env ruby
# frozen_string_literal: true

# ActiveRecord Storage Demo for RubyMCP
# This script demonstrates using ActiveRecord storage with a simple SQLite database

require 'bundler/setup'
require 'ruby_mcp'
require 'active_record'
require 'sqlite3'
require 'fileutils'
require 'logger'
require 'dotenv'

# Load environment variables from .env file
Dotenv.load

# Set up logging
logger = Logger.new($stdout)
logger.level = Logger::INFO

# Create a directory for the database
DB_DIR = File.expand_path('../db', __dir__)
FileUtils.mkdir_p(DB_DIR)
DB_PATH = File.join(DB_DIR, 'mcp_demo.sqlite3')

# Remove existing database file if it exists (for clean demo)
File.delete(DB_PATH) if File.exist?(DB_PATH)

logger.info("Initializing ActiveRecord storage demo with database: #{DB_PATH}")

# Configure RubyMCP
RubyMCP.configure do |config|
  # Load API keys from environment variables
  config.providers = {
    openai: { api_key: ENV['OPENAI_API_KEY'] || 'demo_openai_key' }
  }

  # Configure ActiveRecord storage
  config.storage = :active_record
  config.active_record = {
    connection: {
      adapter: 'sqlite3',
      database: DB_PATH
    },
    table_prefix: 'mcp_'
  }
end

logger.info('RubyMCP configured with ActiveRecord storage')

# Get a client
client = RubyMCP.client

# Helper methods
def print_table_info(db_path, table_name)
  puts "\n--- #{table_name} Table ---"
  db = SQLite3::Database.new(db_path)

  # Get column info
  puts 'Columns:'
  columns = db.execute("PRAGMA table_info(#{table_name})")
  columns.each do |col|
    puts "  #{col[1]} (#{col[2]})"
  end

  # Get row count
  count = db.execute("SELECT COUNT(*) FROM #{table_name}").first.first
  puts "Rows: #{count}"

  # Show data if available
  return unless count.positive?

  puts 'Data:'
  rows = db.execute("SELECT * FROM #{table_name} LIMIT 5")
  rows.each_with_index do |row, i|
    puts "  Row #{i + 1}: #{row.inspect}"
  end
end

def print_all_tables(db_path)
  puts "\n===== DATABASE TABLES =====\n"
  db = SQLite3::Database.new(db_path)
  tables = db.execute("SELECT name FROM sqlite_master WHERE type='table'")

  if tables.empty?
    puts 'No tables found in database.'
  else
    puts 'Tables in database:'
    tables.each do |table|
      puts "- #{table[0]}"

      print_table_info(db_path, table[0])
    end
  end
end

# Function to wait for user input
def pause
  puts "\nPress Enter to continue..."
  gets
end

# Main demo
puts "\n===== RUBY MCP ACTIVERECORD STORAGE DEMO =====\n"
puts 'This demo shows how ActiveRecord storage works with RubyMCP.'
puts 'It creates a real SQLite database and demonstrates storage operations.'
puts 'Press Enter to start...'
gets

# Step 1: Create a context
puts "\n===== STEP 1: CREATE A CONTEXT =====\n"

# Create a context with a properly constructed message object
context = RubyMCP::Models::Context.new(
  metadata: { demo: true, created_at: Time.now.to_s }
)

# Add a system message using the proper Message class
system_message = RubyMCP::Models::Message.new(
  role: 'system',
  content: 'You are a helpful assistant.'
)
context.add_message(system_message)

# Store the context in the database
stored_context = client.storage.create_context(context)

puts "Created context with ID: #{stored_context.id}"
puts "Context metadata: #{stored_context.metadata.inspect}"

print_all_tables(DB_PATH)
pause

# Step 2: Add messages
puts "\n===== STEP 2: ADD MESSAGES =====\n"
client.add_message(stored_context.id, 'user', 'Hello! Can you explain how database storage works?')
client.add_message(stored_context.id, 'assistant', 'Of course! Databases store data in tables with rows and columns...')
client.add_message(stored_context.id, 'user', 'Can you give me an example?')

puts 'Added 3 messages to the context'
print_table_info(DB_PATH, 'mcp_messages')
pause

# Step 3: Store different content types
puts "\n===== STEP 3: STORE DIFFERENT CONTENT TYPES =====\n"

# Text content
text_id = client.add_content(stored_context.id, 'This is plain text content')
puts "Added text content with ID: #{text_id}"

# JSON content
json_id = client.add_content(stored_context.id, {
                               key1: 'value1',
                               key2: { nested: true, array: [1, 2, 3] }
                             })
puts "Added JSON content with ID: #{json_id}"

# Binary content
binary_id = client.add_content(stored_context.id, File.binread(__FILE__)[0..100]) # First 100 bytes of this file
puts "Added binary content with ID: #{binary_id}"

print_table_info(DB_PATH, 'mcp_contents')
pause

# Step 4: Retrieve data
puts "\n===== STEP 4: RETRIEVE DATA =====\n"

# Get the context
retrieved_context = client.get_context(stored_context.id)
puts "Retrieved context ID: #{retrieved_context.id}"
puts "Context has #{retrieved_context.messages.size} messages"
puts "Context metadata: #{retrieved_context.metadata.inspect}"

# Get content
puts "\nRetrieving content:"
puts "Text content: #{client.get_content(stored_context.id, text_id)[0..50]}..."
puts "JSON content: #{client.get_content(stored_context.id, json_id).inspect}"
puts "Binary content: #{client.get_content(stored_context.id, binary_id)[0..20].inspect}..."

pause

# Step 5: Create multiple contexts and list with pagination
puts "\n===== STEP 5: PAGINATION =====\n"

# Create more contexts
3.times do |i|
  new_context = RubyMCP::Models::Context.new(
    metadata: { index: i + 2 }
  )

  # Add a system message to each context
  system_message = RubyMCP::Models::Message.new(
    role: 'system',
    content: "Context #{i + 2}"
  )
  new_context.add_message(system_message)

  # Store the context
  stored_new_context = client.storage.create_context(new_context)
  puts "Created context #{i + 2} with ID: #{stored_new_context.id}"
end

# List with pagination
puts "\nListing contexts with pagination:"
page1 = client.list_contexts(limit: 2, offset: 0)
puts "Page 1 (2 contexts): #{page1.map(&:id).join(', ')}"

page2 = client.list_contexts(limit: 2, offset: 2)
puts "Page 2 (2 contexts): #{page2.map(&:id).join(', ')}"

page3 = client.list_contexts(limit: 2, offset: 4)
puts "Page 3 (remaining): #{page3.map(&:id).join(', ')}"

print_table_info(DB_PATH, 'mcp_contexts')
pause

# Step 6: Delete a context
puts "\n===== STEP 6: DELETE A CONTEXT =====\n"
puts "Deleting context: #{stored_context.id}"
client.delete_context(stored_context.id)

begin
  client.get_context(stored_context.id)
  puts 'ERROR: Context still exists after deletion!'
rescue RubyMCP::Errors::ContextError => e
  puts "✓ Context successfully deleted (#{e.message})"
end

puts "\nVerifying cascade delete removed messages and content:"
print_all_tables(DB_PATH)

# Conclusion
puts "\n===== DEMO COMPLETE =====\n"
puts 'ActiveRecord storage demonstration completed successfully!'
puts "The SQLite database is available at: #{DB_PATH}"
puts 'You can examine it directly with a SQLite browser or the command line:'
puts "  $ sqlite3 #{DB_PATH} '.tables'"
puts "  $ sqlite3 #{DB_PATH} 'SELECT * FROM mcp_contexts;'"
