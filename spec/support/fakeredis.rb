# frozen_string_literal: true

# Add fakeredis to Gemfile if not present:
# gem 'fakeredis', '~> 0.9', group: :test

begin
    require 'fakeredis'
  rescue LoadError
    warn "FakeRedis not available. Add 'fakeredis' to your Gemfile to run Redis tests without a real Redis server."
  end
  
  # Clear fake Redis database before each test
  RSpec.configure do |config|
    config.before(:each) do
      if defined?(Redis::Connection::Memory)
        Redis.new.flushall
      end
    end
  end