# frozen_string_literal: true

require 'json'
require 'securerandom'

module MCP
  module Protocol
    # Implementation of JSON-RPC 2.0 protocol
    # https://www.jsonrpc.org/specification
    module JsonRPC
      # JSON-RPC error codes
      module ErrorCode
        PARSE_ERROR = -32700
        INVALID_REQUEST = -32600
        METHOD_NOT_FOUND = -32601
        INVALID_PARAMS = -32602
        INTERNAL_ERROR = -32603
        
        # Server defined error codes should be between -32000 and -32099
        SERVER_ERROR_MIN = -32099
        SERVER_ERROR_MAX = -32000
      end

      # Creates a JSON-RPC 2.0 request object
      # @param method [String] The method name
      # @param params [Hash, Array, nil] The method parameters
      # @param id [String, Integer, nil] The request ID (nil for notifications)
      # @return [Hash] A JSON-RPC 2.0 request object
      def self.request(method, params = nil, id = SecureRandom.uuid)
        {
          jsonrpc: '2.0',
          method: method,
          params: params,
          id: id
        }.compact
      end

      # Creates a JSON-RPC 2.0 notification object (request without id)
      # @param method [String] The method name
      # @param params [Hash, Array, nil] The method parameters
      # @return [Hash] A JSON-RPC 2.0 notification object
      def self.notification(method, params = nil)
        {
          jsonrpc: '2.0',
          method: method,
          params: params
        }.compact
      end

      # Creates a JSON-RPC 2.0 success response object
      # @param id [String, Integer, nil] The request ID
      # @param result [Object] The result of the method call
      # @return [Hash] A JSON-RPC 2.0 success response object
      def self.success(id, result)
        {
          jsonrpc: '2.0',
          result: result,
          id: id
        }
      end

      # Creates a JSON-RPC 2.0 error response object
      # @param id [String, Integer, nil] The request ID
      # @param code [Integer] The error code
      # @param message [String] The error message
      # @param data [Object, nil] Additional error data
      # @return [Hash] A JSON-RPC 2.0 error response object
      def self.error(id, code, message, data = nil)
        {
          jsonrpc: '2.0',
          error: {
            code: code,
            message: message,
            data: data
          }.compact,
          id: id
        }
      end

      # Parses a JSON-RPC 2.0 message
      # @param json [String] The JSON-RPC message string
      # @return [Hash, Array, Hash] The parsed message or error response
      def self.parse(json)
        JSON.parse(json, symbolize_names: true)
      rescue JSON::ParserError
        error(nil, ErrorCode::PARSE_ERROR, 'Parse error')
      end

      # Validates a JSON-RPC 2.0 request
      # @param request [Hash] The JSON-RPC request
      # @return [nil, Hash] nil if valid, error response if invalid
      def self.validate_request(request)
        return error(nil, ErrorCode::INVALID_REQUEST, 'Invalid Request') unless request.is_a?(Hash)
        
        # Check required fields
        unless request[:jsonrpc] == '2.0' && request[:method].is_a?(String)
          return error(request[:id], ErrorCode::INVALID_REQUEST, 'Invalid Request')
        end

        # Method name should not start with 'rpc.'
        if request[:method].start_with?('rpc.')
          return error(request[:id], ErrorCode::INVALID_REQUEST, 'Method names starting with "rpc." are reserved')
        end

        nil # Valid request
      end

      # Validates a JSON-RPC 2.0 batch request
      # @param batch [Array] The JSON-RPC batch request
      # @return [nil, Hash] nil if valid, error response if invalid
      def self.validate_batch(batch)
        return error(nil, ErrorCode::INVALID_REQUEST, 'Invalid Request') unless batch.is_a?(Array)
        
        # Empty array is invalid
        return error(nil, ErrorCode::INVALID_REQUEST, 'Invalid Request') if batch.empty?
        
        nil # Valid batch
      end

      # Encode a JSON-RPC 2.0 message
      # @param message [Hash, Array] The JSON-RPC message
      # @return [String] The JSON-encoded message
      def self.encode(message)
        JSON.generate(message)
      end
    end
  end
end