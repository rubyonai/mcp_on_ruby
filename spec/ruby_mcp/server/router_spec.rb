# spec/ruby_mcp/server/router_spec.rb
require 'spec_helper'

RSpec.describe RubyMCP::Server::Router do
  let(:router) { described_class.new }
  
  describe "#add" do
    it "adds a route to the routes collection" do
      router.add("GET", "/test", Object, :index)
      expect(router.instance_variable_get(:@routes).size).to eq(1)
      expect(router.instance_variable_get(:@routes).first.method).to eq("GET")
      expect(router.instance_variable_get(:@routes).first.path).to eq("/test")
    end
  end
  
  describe "#route" do
    let(:controller_class) do
      Class.new(RubyMCP::Server::BaseController) do
        def index
          [200, {}, ["Test"]]
        end
      end
    end
    
    let(:request) do
      Rack::Request.new({
        "REQUEST_METHOD" => "GET",
        "PATH_INFO" => "/test",
        "rack.input" => StringIO.new
      })
    end
    
    before do
      router.add("GET", "/test", controller_class, :index)
    end
    
    it "routes the request to the correct controller and action" do
      response = router.route(request)
      expect(response).to eq([200, {}, ["Test"]])
    end
    
    it "extracts params from path segments" do
      router.add("GET", "/users/:id", controller_class, :index)
      
      user_request = Rack::Request.new({
        "REQUEST_METHOD" => "GET",
        "PATH_INFO" => "/users/123",
        "rack.input" => StringIO.new
      })
      
      expect_any_instance_of(controller_class).to receive(:index) do |instance|
        expect(instance.params[:id]).to eq("123")
        [200, {}, ["Test"]]
      end
      
      router.route(user_request)
    end
    
    it "returns nil when no route matches" do
      not_found_request = Rack::Request.new({
        "REQUEST_METHOD" => "GET",
        "PATH_INFO" => "/not_found",
        "rack.input" => StringIO.new
      })
      
      expect(router.route(not_found_request)).to be_nil
    end
  end
end