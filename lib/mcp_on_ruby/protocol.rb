# frozen_string_literal: true

require_relative 'protocol/json_rpc'
require_relative 'protocol/types'
require_relative 'protocol/connection'
require_relative 'protocol/transport/base'
require_relative 'protocol/transport/http'
require_relative 'protocol/transport/http_server'
require_relative 'protocol/transport/stdio'

module MCP
  # Module for MCP protocol implementation
  module Protocol
    # Create a transport instance based on the options
    # @param options [Hash] The transport options
    # @return [Transport::Base] A transport instance
    def self.create_transport(options)
      transport_type = options[:transport] || :http
      mode = options[:mode] || :client
      
      case transport_type
      when :http
        if mode == :server
          Transport::HTTPServer.new(options)
        else
          Transport::HTTP.new(options)
        end
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
    
    # Create an MCP server
    # @param options [Hash] The server options
    # @return [Transport::Base] A server transport instance
    def self.create_server(options = {})
      server_options = options.merge(mode: :server)
      create_transport(server_options)
    end
  end
end