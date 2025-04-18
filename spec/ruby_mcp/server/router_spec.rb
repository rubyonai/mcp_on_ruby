# spec/ruby_mcp/server/router_spec.rb
require 'spec_helper'

RSpec.describe RubyMCP::Server::Router do
  let(:router) { described_class.new }
  
  describe "#path_matches?" do
    it "matches exact paths" do
      expect(router.send(:path_matches?, "/test", "/test")).to be true
    end
    
    it "matches paths with parameters" do
      expect(router.send(:path_matches?, "/users/:id", "/users/123")).to be true
    end
    
    it "doesn't match paths with different segment counts" do
      expect(router.send(:path_matches?, "/users/:id", "/users")).to be false
      expect(router.send(:path_matches?, "/users", "/users/123")).to be false
    end
    
    it "doesn't match paths with different static segments" do
      expect(router.send(:path_matches?, "/users/:id", "/posts/123")).to be false
    end
  end
  
  describe "#extract_params" do
    it "extracts parameters from path segments" do
      params = router.send(:extract_params, "/users/:id/posts/:post_id", "/users/123/posts/456")
      expect(params).to eq({ id: "123", post_id: "456" })
    end
    
    it "returns an empty hash for paths without parameters" do
      params = router.send(:extract_params, "/status", "/status")
      expect(params).to eq({})
    end
  end
  
  describe "#extract_query_params" do
    it "extracts query parameters from the request" do
      request = Rack::Request.new(Rack::MockRequest.env_for("/?page=1&limit=10"))
      params = router.send(:extract_query_params, request)
      expect(params).to include(page: "1", limit: "10")
    end
  end
end