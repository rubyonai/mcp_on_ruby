# frozen_string_literal: true

if defined?(Rails)
  module McpOnRuby
    # Rails integration via Railtie
    class Railtie < Rails::Railtie
      # Add MCP-specific directories to Rails autoload paths
      initializer "mcp_on_ruby.setup_autoload_paths" do |app|
        # Add app/tools and app/resources to autoload paths
        %w[tools resources].each do |dir|
          path = app.root.join("app", dir)
          app.config.autoload_paths << path.to_s if path.exist?
        end
      end

      # Set up Rails-friendly aliases
      initializer "mcp_on_ruby.setup_aliases" do
        # Create Rails-style base classes
        Object.const_set('ApplicationTool', Class.new(McpOnRuby::Tool)) unless defined?(ApplicationTool)
        Object.const_set('ApplicationResource', Class.new(McpOnRuby::Resource)) unless defined?(ApplicationResource)
      end

      # Configure MCP server if needed
      initializer "mcp_on_ruby.configure" do |app|
        # Set up default configuration
        McpOnRuby.configure do |config|
          config.log_level = Rails.logger.level
        end

        # Add MCP configuration to Rails application
        app.config.mcp = ActiveSupport::OrderedOptions.new
        app.config.mcp.enabled = false
        app.config.mcp.path = '/mcp'
        app.config.mcp.authentication_required = false
        app.config.mcp.authentication_token = nil
        app.config.mcp.rate_limit_per_minute = 60
        app.config.mcp.auto_register_tools = true
        app.config.mcp.auto_register_resources = true
      end

      # Auto-register tools and resources after application initialization
      config.after_initialize do |app|
        next unless app.config.mcp.enabled

        # Create MCP server instance
        server = McpOnRuby.server do |s|
          # Auto-register tools if enabled
          if app.config.mcp.auto_register_tools && defined?(ApplicationTool)
            ApplicationTool.descendants.each do |tool_class|
              instance = tool_class.new
              s.register_tool(instance)
            end
          end

          # Auto-register resources if enabled
          if app.config.mcp.auto_register_resources && defined?(ApplicationResource)
            ApplicationResource.descendants.each do |resource_class|
              instance = resource_class.new
              s.register_resource(instance)
            end
          end
        end

        # Mount the server middleware
        app.config.middleware.use(
          McpOnRuby::Transport::RackMiddleware,
          server: server,
          path: app.config.mcp.path,
          authentication_required: app.config.mcp.authentication_required,
          authentication_token: app.config.mcp.authentication_token,
          rate_limit_per_minute: app.config.mcp.rate_limit_per_minute
        )

        # Store server reference for manual access
        app.config.mcp_server = server
      end

      # Add rake tasks (uncomment when tasks file is created)
      # rake_tasks do
      #   load File.expand_path('tasks/mcp.rake', __dir__)
      # end

      # Add generators
      generators do
        require_relative 'generators/install_generator'
        require_relative 'generators/tool_generator'
        require_relative 'generators/resource_generator'
      end
    end
  end
end