# frozen_string_literal: true

require "dry-schema"

module RubyMCP
  module Schemas
    # Define schemas using dry-schema
    
    ContextSchema = Dry::Schema.JSON do
      optional(:id).maybe(:string).filled(format?: /^ctx_[a-zA-Z0-9]+$/)
      
      optional(:messages).array(:hash) do
        required(:role).filled(:string, included_in?: ["user", "assistant", "system", "tool"])
        required(:content).filled
        optional(:id).maybe(:string)
        optional(:metadata).maybe(:hash)
      end
      
      optional(:metadata).maybe(:hash)
    end
    
    MessageSchema = Dry::Schema.JSON do
      required(:context_id).filled(:string, format?: /^ctx_[a-zA-Z0-9]+$/)
      required(:role).filled(:string, included_in?: ["user", "assistant", "system", "tool"])
      required(:content).filled
      optional(:id).maybe(:string)
      optional(:metadata).maybe(:hash)
    end
    
    GenerateSchema = Dry::Schema.JSON do
      required(:context_id).filled(:string, format?: /^ctx_[a-zA-Z0-9]+$/)
      required(:engine_id).filled(:string, format?: /^[a-z0-9-]+\/[a-z0-9-]+$/)
      
      optional(:max_tokens).maybe(:integer, gt?: 0)
      optional(:temperature).maybe(:float, gteq?: 0, lteq?: 2)
      optional(:top_p).maybe(:float, gteq?: 0, lteq?: 1)
      optional(:frequency_penalty).maybe(:float, gteq?: -2, lteq?: 2)
      optional(:presence_penalty).maybe(:float, gteq?: -2, lteq?: 2)
      optional(:stop).maybe(:string)
      optional(:update_context).maybe(:bool)
      
      # Tool calling support could be added here
    end
    
    ContentSchema = Dry::Schema.JSON do
      required(:context_id).filled(:string, format?: /^ctx_[a-zA-Z0-9]+$/)
      optional(:id).maybe(:string)
      optional(:type).maybe(:string)
      
      optional(:file_data).maybe(:string)
      optional(:filename).maybe(:string)
      optional(:content_type).maybe(:string)
      optional(:data).maybe(:hash)
    end
  end
end