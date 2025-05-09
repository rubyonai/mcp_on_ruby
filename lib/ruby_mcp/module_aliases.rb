# frozen_string_literal: true

# This file contains aliases for MCP modules to ensure consistent access patterns
# between the implementation and tests.

module MCP
  # These module constants provide direct access to the submodules
  # so that both MCP::Client::X and MCP::Client access patterns work
  Client = ::MCP::Client unless defined?(MCP::Client)
  Server = ::MCP::Server unless defined?(MCP::Server)
  Protocol = ::MCP::Protocol unless defined?(MCP::Protocol)
  
  # Explicitly expose the JsonRPC class for tests
  module Protocol
    # Ensure JsonRPC is available
    JsonRPC = ::MCP::Protocol::JsonRPC unless defined?(MCP::Protocol::JsonRPC)
  end
  
  # Explicitly expose Client classes for tests
  module Client
    # Ensure Client classes are available
    Client = ::MCP::Client::Client unless defined?(MCP::Client::Client)
    Auth = ::MCP::Client::Auth unless defined?(MCP::Client::Auth)
    Retry = ::MCP::Client::Retry unless defined?(MCP::Client::Retry)
    Streaming = ::MCP::Client::Streaming unless defined?(MCP::Client::Streaming)
  end
  
  # Explicitly expose Server classes for tests
  module Server
    # Ensure Server classes are available
    Server = ::MCP::Server::Server unless defined?(MCP::Server::Server)
    DSL = ::MCP::Server::DSL unless defined?(MCP::Server::DSL)
    Auth = ::MCP::Server::Auth unless defined?(MCP::Server::Auth)
    
    module Auth
      OAuth = ::MCP::Server::Auth::OAuth unless defined?(MCP::Server::Auth::OAuth)
      Permissions = ::MCP::Server::Auth::Permissions unless defined?(MCP::Server::Auth::Permissions)
      Middleware = ::MCP::Server::Auth::Middleware unless defined?(MCP::Server::Auth::Middleware)
    end
    
    module Tools
      Tool = ::MCP::Server::Tools::Tool unless defined?(MCP::Server::Tools::Tool)
      Manager = ::MCP::Server::Tools::Manager unless defined?(MCP::Server::Tools::Manager)
    end
    
    module Resources
      Resource = ::MCP::Server::Resources::Resource unless defined?(MCP::Server::Resources::Resource)
      Manager = ::MCP::Server::Resources::Manager unless defined?(MCP::Server::Resources::Manager)
    end
    
    module Prompts
      Prompt = ::MCP::Server::Prompts::Prompt unless defined?(MCP::Server::Prompts::Prompt)
      Manager = ::MCP::Server::Prompts::Manager unless defined?(MCP::Server::Prompts::Manager)
    end
    
    module Roots
      Root = ::MCP::Server::Roots::Root unless defined?(MCP::Server::Roots::Root)
      Manager = ::MCP::Server::Roots::Manager unless defined?(MCP::Server::Roots::Manager)
    end
  end
end