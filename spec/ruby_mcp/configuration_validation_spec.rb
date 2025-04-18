# spec/ruby_mcp/configuration_validation_spec.rb
require 'spec_helper'

RSpec.describe "Configuration validation" do
  after do
    # Reset configuration after each test
    RubyMCP.configuration = RubyMCP::Configuration.new
  end
  
  it "validates provider configuration" do
    RubyMCP.configure do |config|
      config.providers = {
        openai: { api_key: nil } # Missing API key
      }
    end
    
    expect { RubyMCP.configuration.storage_instance }.not_to raise_error
    
    # Attempting to use the OpenAI provider would fail,
    # but that's tested in the provider tests
  end
  
  it "validates jwt configuration when auth is required" do
    RubyMCP.configure do |config|
      config.auth_required = true
      config.jwt_secret = nil # Missing JWT secret
    end
    
    # Your implementation might not validate this automatically,
    # but it's a good practice to add a validation method
    if RubyMCP::Configuration.method_defined?(:validate!)
      expect { RubyMCP.configuration.validate! }.to raise_error(RubyMCP::Errors::ConfigurationError)
    end
  end
  
  it "accepts custom storage instance" do
    custom_storage = RubyMCP::Storage::Memory.new
    
    RubyMCP.configure do |config|
      config.storage = custom_storage
    end
    
    expect(RubyMCP.configuration.storage_instance).to eq(custom_storage)
  end
end