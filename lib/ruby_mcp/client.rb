# lib/ruby_mcp/client.rb
# frozen_string_literal: true

module RubyMCP
  class Client
    attr_reader :storage

    def initialize(storage)
      @storage = storage
    end

    # You can add additional convenience methods here
    # that delegate to storage or provide higher-level functionality
  end
end
