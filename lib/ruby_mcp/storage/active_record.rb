# frozen_string_literal: true

begin
    require 'active_record'
  rescue LoadError
    # ActiveRecord is an optional dependency
    # This error will be handled by the storage factory
  end
  
  require 'securerandom'
  require 'json'
  require_relative 'base'
  
  module RubyMCP
    module Storage
      # ActiveRecord-based storage implementation for RubyMCP
      class ActiveRecord < Base
        # Initialize ActiveRecord storage with options
        # @param options [Hash] Options for ActiveRecord storage
        # @option options [Hash] :connection ActiveRecord connection configuration
        # @option options [String] :table_prefix Prefix for table names (default: 'mcp_')
        def initialize(options = {})
          super
          @table_prefix = options[:table_prefix] || 'mcp_'
          
          # Set up ActiveRecord connection if provided
          if options[:connection].is_a?(Hash)
            ::ActiveRecord::Base.establish_connection(options[:connection])
          end
          
          setup_models
          ensure_tables_exist
        end
  
        # Create a new context
        # @param context [RubyMCP::Models::Context] Context to create
        # @return [RubyMCP::Models::Context] Created context
        def create_context(context)
          # Check if context already exists
          if @context_model.exists?(external_id: context.id)
            raise RubyMCP::Errors::ContextError, "Context already exists: #{context.id}"
          end
  
          # Create the context record
          ar_context = @context_model.create!(
            external_id: context.id,
            metadata: JSON.generate(context.metadata || {}),
            created_at: context.created_at,
            updated_at: context.updated_at
          )
  
          # Create message records if any
          context.messages.each do |message|
            create_message_record(ar_context.id, message)
          end
  
          # Create content records if any
          context.content_map.each do |content_id, content_data|
            create_content_record(ar_context.id, content_id, content_data)
          end
  
          context
        end
  
        # Get a context by ID
        # @param context_id [String] ID of the context to get
        # @return [RubyMCP::Models::Context] Found context
        # @raise [RubyMCP::Errors::ContextError] If context not found
        def get_context(context_id)
          ar_context = @context_model.find_by(external_id: context_id)
          raise RubyMCP::Errors::ContextError, "Context not found: #{context_id}" unless ar_context
  
          # Parse metadata
          metadata = begin
            json = JSON.parse(ar_context.metadata)
            symbolize_keys(json)
          rescue
            {}
          end
  
          # Create a new context object
          context = RubyMCP::Models::Context.new(
            id: ar_context.external_id,
            metadata: metadata
          )
  
          # Set timestamps
          context.instance_variable_set(:@created_at, ar_context.created_at)
          context.instance_variable_set(:@updated_at, ar_context.updated_at)
  
          # Load messages
          ar_messages = @message_model.where(context_id: ar_context.id).order(:created_at)
          ar_messages.each do |ar_message|
            # Parse message metadata
            msg_metadata = begin
              json = JSON.parse(ar_message.metadata)
              symbolize_keys(json)
            rescue
              {}
            end
          
            message = RubyMCP::Models::Message.new(
              id: ar_message.external_id,
              role: ar_message.role,
              content: ar_message.content,
              metadata: msg_metadata
            )
            message.instance_variable_set(:@created_at, ar_message.created_at)
            context.instance_variable_get(:@messages) << message
          end
  
          # Load content
          ar_contents = @content_model.where(context_id: ar_context.id)
          ar_contents.each do |ar_content|
            content_data = if ar_content.content_type == 'json'
                             begin
                               JSON.parse(ar_content.data_json)
                             rescue
                               {}
                             end
                           else
                             ar_content.data_binary
                           end
            context.instance_variable_get(:@content_map)[ar_content.external_id] = content_data
          end
  
          context
        end
  
        # Update a context
        # @param context [RubyMCP::Models::Context] Context to update
        # @return [RubyMCP::Models::Context] Updated context
        # @raise [RubyMCP::Errors::ContextError] If context not found
        def update_context(context)
          ar_context = @context_model.find_by(external_id: context.id)
          raise RubyMCP::Errors::ContextError, "Context not found: #{context.id}" unless ar_context
  
          # Update the context record
          ar_context.update!(
            metadata: JSON.generate(context.metadata || {}),
            updated_at: context.updated_at
          )
  
          # We don't update messages or content here as they are added separately
          context
        end
  
        # Delete a context
        # @param context_id [String] ID of the context to delete
        # @return [Boolean] True if deleted
        # @raise [RubyMCP::Errors::ContextError] If context not found
        def delete_context(context_id)
          ar_context = @context_model.find_by(external_id: context_id)
          raise RubyMCP::Errors::ContextError, "Context not found: #{context_id}" unless ar_context
  
          # Delete all related records manually since we can't rely on cascading in tests
          @message_model.where(context_id: ar_context.id).delete_all
          @content_model.where(context_id: ar_context.id).delete_all
          ar_context.destroy
  
          true
        end
  
        # List contexts with pagination
        # @param limit [Integer] Maximum number of contexts to return
        # @param offset [Integer] Number of contexts to skip
        # @return [Array<RubyMCP::Models::Context>] List of contexts
        def list_contexts(limit: 100, offset: 0)
          ar_contexts = @context_model.order(updated_at: :desc).limit(limit).offset(offset)
          
          ar_contexts.map do |ar_context|
            get_context(ar_context.external_id)
          end
        end
  
        # Add a message to a context
        # @param context_id [String] ID of the context
        # @param message [RubyMCP::Models::Message] Message to add
        # @return [RubyMCP::Models::Message] Added message
        # @raise [RubyMCP::Errors::ContextError] If context not found
        def add_message(context_id, message)
          ar_context = @context_model.find_by(external_id: context_id)
          raise RubyMCP::Errors::ContextError, "Context not found: #{context_id}" unless ar_context
  
          # Create the message record
          create_message_record(ar_context.id, message)
  
          # Update the context's updated_at timestamp
          ar_context.touch
  
          message
        end
  
        # Add content to a context
        # @param context_id [String] ID of the context
        # @param content_id [String] ID of the content
        # @param content_data [Object] Content data
        # @return [String] Content ID
        # @raise [RubyMCP::Errors::ContextError] If context not found
        def add_content(context_id, content_id, content_data)
          ar_context = @context_model.find_by(external_id: context_id)
          raise RubyMCP::Errors::ContextError, "Context not found: #{context_id}" unless ar_context
  
          # Create the content record
          create_content_record(ar_context.id, content_id, content_data)
  
          # Update the context's updated_at timestamp
          ar_context.touch
  
          content_id
        end
  
        # Get content from a context
        # @param context_id [String] ID of the context
        # @param content_id [String] ID of the content
        # @return [Object] Content data
        # @raise [RubyMCP::Errors::ContextError] If context not found
        # @raise [RubyMCP::Errors::ContentError] If content not found
        def get_content(context_id, content_id)
          ar_context = @context_model.find_by(external_id: context_id)
          raise RubyMCP::Errors::ContextError, "Context not found: #{context_id}" unless ar_context
  
          ar_content = @content_model.find_by(context_id: ar_context.id, external_id: content_id)
          raise RubyMCP::Errors::ContentError, "Content not found: #{content_id}" unless ar_content
  
          if ar_content.content_type == 'json'
            begin
              json = JSON.parse(ar_content.data_json)
              symbolize_keys(json)
            rescue
              {}
            end
          else
            ar_content.data_binary
          end
        end
  
        private
  
        # Setup model classes
        def setup_models
          prefix = @table_prefix
          
          # Context model
          @context_model = Class.new(::ActiveRecord::Base) do
            self.table_name = "#{prefix}contexts"
          end
          Object.const_set("MCPContext#{SecureRandom.hex(4)}", @context_model)
          
          # Message model
          @message_model = Class.new(::ActiveRecord::Base) do
            self.table_name = "#{prefix}messages"
          end
          Object.const_set("MCPMessage#{SecureRandom.hex(4)}", @message_model)
          
          # Content model
          @content_model = Class.new(::ActiveRecord::Base) do
            self.table_name = "#{prefix}contents"
          end
          Object.const_set("MCPContent#{SecureRandom.hex(4)}", @content_model)
        end
  
        # Ensure necessary tables exist
        def ensure_tables_exist
          connection = ::ActiveRecord::Base.connection
          
          # Drop tables if they exist (for clean setup)
          if connection.table_exists?("#{@table_prefix}contents")
            connection.drop_table("#{@table_prefix}contents")
          end
          
          if connection.table_exists?("#{@table_prefix}messages")
            connection.drop_table("#{@table_prefix}messages")
          end
          
          if connection.table_exists?("#{@table_prefix}contexts")
            connection.drop_table("#{@table_prefix}contexts")
          end
          
          # Create tables in proper order
          create_contexts_table
          create_messages_table
          create_contents_table
        end
  
        # Check if a table exists
        def table_exists?(table_name)
          ::ActiveRecord::Base.connection.table_exists?(table_name)
        end
  
        # Create the contexts table
        def create_contexts_table
          connection = ::ActiveRecord::Base.connection
          connection.create_table("#{@table_prefix}contexts") do |t|
            t.string :external_id, null: false
            t.text :metadata, default: '{}'
            t.timestamps
          end
          connection.add_index("#{@table_prefix}contexts", :external_id, unique: true)
          connection.add_index("#{@table_prefix}contexts", :updated_at)
        end
  
        # Create the messages table
        def create_messages_table
          connection = ::ActiveRecord::Base.connection
          connection.create_table("#{@table_prefix}messages") do |t|
            t.bigint :context_id, null: false
            t.string :external_id, null: false
            t.string :role, null: false
            t.text :content, null: false
            t.text :metadata, default: '{}'
            t.timestamps
          end
          connection.add_index("#{@table_prefix}messages", [:context_id, :external_id], unique: true)
          connection.add_index("#{@table_prefix}messages", :context_id)
        end
  
        # Create the contents table
        def create_contents_table
          connection = ::ActiveRecord::Base.connection
          connection.create_table("#{@table_prefix}contents") do |t|
            t.bigint :context_id, null: false
            t.string :external_id, null: false
            t.binary :data_binary
            t.text :data_json
            t.string :content_type
            t.timestamps
          end
          connection.add_index("#{@table_prefix}contents", [:context_id, :external_id], unique: true)
          connection.add_index("#{@table_prefix}contents", :context_id)
        end
  
        # Create a message record
        def create_message_record(context_id, message)
          @message_model.create!(
            context_id: context_id,
            external_id: message.id,
            role: message.role,
            content: message.content.to_s,
            metadata: JSON.generate(message.metadata || {}),
            created_at: message.created_at
          )
        end
  
        # Create a content record
        def create_content_record(context_id, content_id, content_data)
          if content_data.is_a?(Hash) || content_data.is_a?(Array)
            @content_model.create!(
              context_id: context_id,
              external_id: content_id,
              data_json: JSON.generate(content_data),
              content_type: 'json'
            )
          else
            @content_model.create!(
              context_id: context_id,
              external_id: content_id,
              data_binary: content_data.to_s,
              content_type: 'binary'
            )
          end
        end
        
        # Helper method to symbolize keys in hashes (including nested ones)
        def symbolize_keys(obj)
          case obj
          when Hash
            obj.each_with_object({}) do |(key, value), result|
              result[key.to_sym] = symbolize_keys(value)
            end
          when Array
            obj.map { |item| symbolize_keys(item) }
          else
            obj
          end
        end
      end
    end
  end