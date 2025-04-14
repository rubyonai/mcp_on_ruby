# frozen_string_literal: true

module RubyMCP
    module Models
      class Engine
        attr_reader :id, :provider, :model, :capabilities, :config
  
        def initialize(id:, provider:, model:, capabilities: [], config: {})
          @id = id
          @provider = provider
          @model = model
          @capabilities = capabilities
          @config = config
        end
  
        def to_h
          {
            id: @id,
            provider: @provider,
            model: @model,
            capabilities: @capabilities,
            config: @config
          }
        end
  
        def supports?(capability)
          @capabilities.include?(capability.to_s)
        end
      end
    end
  end