# frozen_string_literal: true

module MCP
  module Client
    # Retry policy for client operations
    class RetryPolicy
      attr_reader :max_retries, :retry_interval, :max_retry_interval, :retry_multiplier
      
      def initialize(options = {})
        @max_retries = options[:max_retries] || 3
        @retry_interval = options[:retry_interval] || 1.0
        @max_retry_interval = options[:max_retry_interval] || 30.0
        @retry_multiplier = options[:retry_multiplier] || 2.0
      end
      
      # Execute a block with retry
      # @param retriable_errors [Array<Class>] The errors to retry on
      # @param retry_condition [Proc] Optional condition for retry
      # @yield The block to execute
      # @return [Object] The result of the block
      def with_retry(retriable_errors = [StandardError], retry_condition = nil)
        retries = 0
        interval = @retry_interval
        
        begin
          yield
        rescue *retriable_errors => e
          retries += 1
          
          if retries <= @max_retries && (retry_condition.nil? || retry_condition.call(e, retries))
            sleep interval
            interval = [interval * @retry_multiplier, @max_retry_interval].min
            retry
          end
          
          raise
        end
      end
    end
    
    # Retry mechanism for client operations
    module Retry
      # Execute a block with retry
      # @param options [Hash] The retry options
      # @param retriable_errors [Array<Class>] The errors to retry on
      # @param retry_condition [Proc] Optional condition for retry
      # @yield The block to execute
      # @return [Object] The result of the block
      def with_retry(options = {}, retriable_errors = [StandardError], retry_condition = nil, &block)
        policy = RetryPolicy.new(options)
        policy.with_retry(retriable_errors, retry_condition, &block)
      end
    end
  end
end