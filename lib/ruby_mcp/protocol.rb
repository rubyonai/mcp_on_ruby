# frozen_string_literal: true

require_relative 'protocol/json_rpc'
require_relative 'protocol/types'
require_relative 'protocol/connection'
require_relative 'protocol/transport/base'
require_relative 'protocol/transport/http'
require_relative 'protocol/transport/stdio'

module MCP
  # Module for MCP protocol implementation
  module Protocol
    # Create a transport instance based on the options
    # @param options [Hash] The transport options
    # @return [Transport::Base] A transport instance
    def self.create_transport(options)
      transport_type = options[:transport] || :http
      
      case transport_type
      when :http
        Transport::HTTP.new(options)
      when :stdio
        Transport::STDIO.new(options)
      else
        raise ArgumentError, "Unknown transport type: #{transport_type}"
      end
    end
    
    # Create a connection to an MCP server
    # @param options [Hash] The connection options
    # @return [Connection] A connection instance
    def self.connect(options = {})
      transport = create_transport(options)
      connection = Connection.new(transport.connect)
      
      # Initialize the connection
      connection.initialize_connection(options)
      
      connection
    end
  end
end