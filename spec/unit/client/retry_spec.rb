# frozen_string_literal: true

RSpec.describe MCP::Client::Retry do
  let(:client) { Object.new.extend(described_class) }
  
  before do
    client.instance_variable_set(:@logger, Logger.new(nil))
    client.instance_variable_set(:@max_retries, 3)
    client.instance_variable_set(:@base_delay, 0.01) # Small for faster tests
    client.instance_variable_set(:@max_delay, 0.05)  # Small for faster tests
  end
  
  describe '#with_retry' do
    context 'when operation succeeds' do
      it 'yields to the block once and returns the result' do
        counter = 0
        result = client.with_retry do
          counter += 1
          'success'
        end
        
        expect(counter).to eq(1)
        expect(result).to eq('success')
      end
    end
    
    context 'when operation fails' do
      it 'retries the operation up to max_retries times' do
        counter = 0
        allow(client).to receive(:sleep) # Don't actually sleep in tests
        
        expect {
          client.with_retry do
            counter += 1
            raise StandardError, 'Operation failed'
          end
        }.to raise_error(StandardError, 'Operation failed')
        
        expect(counter).to eq(4) # Initial attempt + 3 retries
      end
      
      it 'returns the result if a retry succeeds' do
        counter = 0
        allow(client).to receive(:sleep)
        
        result = client.with_retry do
          counter += 1
          if counter < 3
            raise StandardError, 'Operation failed'
          else
            'success on retry'
          end
        end
        
        expect(counter).to eq(3)
        expect(result).to eq('success on retry')
      end
      
      it 'calculates backoff delay correctly' do
        # We can test the calculateBackoff method directly
        expect(client.send(:calculate_backoff, 1)).to be_between(0.01, 0.02)
        expect(client.send(:calculate_backoff, 2)).to be_between(0.01, 0.04)
        expect(client.send(:calculate_backoff, 3)).to be_between(0.01, 0.05) # Capped at max_delay
      end
      
      it 'logs warning messages for retries' do
        logger = double
        client.instance_variable_set(:@logger, logger)
        allow(client).to receive(:sleep)
        
        expect(logger).to receive(:warn).exactly(3).times
        
        begin
          client.with_retry do
            raise StandardError, 'Operation failed'
          end
        rescue StandardError
          # Expected
        end
      end
    end
  end
  
  describe '#is_retriable_error?' do
    it 'returns true for connection errors' do
      error = MCP::Errors::ConnectionError.new('Connection error')
      expect(client.send(:is_retriable_error?, error)).to be(true)
    end
    
    it 'returns true for timeout errors' do
      error = Timeout::Error.new('Timeout error')
      expect(client.send(:is_retriable_error?, error)).to be(true)
    end
    
    it 'returns true for temporary server errors' do
      error = MCP::Errors::ServerError.new('Server error')
      expect(client.send(:is_retriable_error?, error)).to be(true)
    end
    
    it 'returns false for validation errors' do
      error = MCP::Errors::ValidationError.new('Validation error')
      expect(client.send(:is_retriable_error?, error)).to be(false)
    end
    
    it 'returns false for tool not found errors' do
      error = MCP::Errors::ToolNotFoundError.new('Tool not found')
      expect(client.send(:is_retriable_error?, error)).to be(false)
    end
    
    it 'returns false for other errors' do
      error = ArgumentError.new('Invalid argument')
      expect(client.send(:is_retriable_error?, error)).to be(false)
    end
  end
end