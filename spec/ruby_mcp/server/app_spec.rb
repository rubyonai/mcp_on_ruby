# spec/ruby_mcp/server/app_spec.rb
require 'spec_helper'
require 'rack/test'

RSpec.describe RubyMCP::Server::App do
  include Rack::Test::Methods
  
  let(:config) { RubyMCP::Configuration.new }
  let(:app) { described_class.new(config).rack_app }
  
  describe "#call" do
    it "handles CORS preflight requests" do
      options "/"
      expect(last_response.status).to eq(200)
    end
    
    it "returns 404 for unknown routes" do
      get "/unknown_route"
      expect(last_response.status).to eq(404)
      expect(JSON.parse(last_response.body)["error"]).to eq("Not found")
    end
    
    context "with authentication required" do
      let(:config) do
        RubyMCP::Configuration.new.tap do |c|
          c.auth_required = true
          c.jwt_secret = "test_secret"
        end
      end
      
      it "returns 401 for requests without authentication" do
        get "/engines"
        expect(last_response.status).to eq(401)
        expect(JSON.parse(last_response.body)["error"]).to eq("Unauthorized")
      end
      
      it "processes authenticated requests" do
        token = JWT.encode({sub: "test", exp: Time.now.to_i + 3600}, config.jwt_secret, "HS256")
        get "/engines", {}, {"HTTP_AUTHORIZATION" => "Bearer #{token}"}
        
        # This would normally return engines, but our mock setup may not have any
        # Just check that it's not a 401
        expect(last_response.status).to_not eq(401)
      end
    end
  end
end