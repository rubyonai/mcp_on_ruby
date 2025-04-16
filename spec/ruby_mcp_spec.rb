# frozen_string_literal: true

# frozen_string_literal: true

RSpec.describe RubyMCP do
  it "has a version number" do
    expect(RubyMCP::VERSION).not_to be nil
  end

  it "can be configured with a block" do
    RubyMCP.configure do |config|
      config.server_port = 8888
    end

    expect(RubyMCP.configuration.server_port).to eq(8888)
  end
end
