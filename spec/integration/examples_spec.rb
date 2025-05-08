# frozen_string_literal: true

RSpec.describe "Example code verification" do
  # Test the simple server example
  describe "Simple server example" do
    it "defines and uses a server with tools and resources" do
      # Mock parts that would require a real server
      transport = double('Transport', connect: nil, disconnect: nil, connected?: true)
      connection = double('Connection')
      
      # Allow creating and connecting to the server
      allow(MCP::Protocol).to receive(:create_server).and_return(transport)
      allow(transport).to receive(:set_auth_middleware)
      allow(transport).to receive(:instance_variable_get).with(any_args).and_return(nil)
      
      # Create a server according to the example
      server = MCP::Server.new do |s|
        # Define a tool
        s.tool "weather.get_forecast" do |t|
          t.parameter :location, :string, description: "City name or coordinates"
          t.parameter :days, :integer, description: "Number of days to forecast", default: 3
          
          t.execute do |params|
            location = params[:location]
            days = params[:days]
            
            # Mock weather data
            forecast = [
              { date: Date.today.to_s, conditions: "Sunny", temp: 72 },
              { date: (Date.today + 1).to_s, conditions: "Partly Cloudy", temp: 68 },
              { date: (Date.today + 2).to_s, conditions: "Rainy", temp: 62 }
            ].first(days)
            
            { location: location, forecast: forecast }
          end
        end
        
        # Add a resource
        s.resource "user.profile" do
          {
            name: "John",
            email: "john@example.com",
            preferences: {
              theme: "dark",
              notifications: true
            }
          }
        end
      end
      
      # Verify the server has the tool and resource
      tools_manager = server.instance_variable_get(:@server).instance_variable_get(:@tools_manager)
      resources_manager = server.instance_variable_get(:@server).instance_variable_get(:@resources_manager)
      
      expect(tools_manager.list.map { |t| t[:name] }).to include('weather.get_forecast')
      expect(resources_manager.list.map { |r| r[:name] }).to include('user.profile')
      
      # Verify the tool works
      tool = tools_manager.get('weather.get_forecast')
      result = tool.call({ location: 'San Francisco', days: 2 })
      
      expect(result[:location]).to eq('San Francisco')
      expect(result[:forecast].length).to eq(2)
      
      # Verify the resource works
      resource = resources_manager.get('user.profile')
      data = resource.get_data
      
      expect(data[:name]).to eq('John')
      expect(data[:email]).to eq('john@example.com')
      expect(data[:preferences][:theme]).to eq('dark')
    end
  end
  
  # Test the simple client example
  describe "Simple client example" do
    it "creates a client and connects to a server" do
      # Mock the transport and connection
      transport = double('Transport', connect: nil, disconnect: nil, connected?: true)
      connection = double('Connection')
      
      # Mock initialization and method calls
      server_info = {
        name: 'Test Server',
        version: '1.0.0'
      }
      
      tools_list = [
        { name: 'weather.get_forecast', schema: {} }
      ]
      
      forecast_result = {
        location: 'San Francisco',
        forecast: [
          { date: Date.today.to_s, conditions: 'Sunny', temp: 72 }
        ]
      }
      
      profile_data = {
        name: 'John',
        email: 'john@example.com',
        preferences: {
          theme: 'dark'
        }
      }
      
      # Set up the connection's behavior
      allow(MCP::Protocol).to receive(:create_transport).and_return(transport)
      allow(transport).to receive(:connect).and_return(connection)
      allow(connection).to receive(:initialize_connection).and_return({
        serverInfo: server_info,
        protocolVersion: MCP::PROTOCOL_VERSION,
        capabilities: {}
      })
      
      allow(connection).to receive(:send_request).with('tools/list', anything).and_return(tools_list)
      allow(connection).to receive(:send_request).with('tools/call', hash_including(name: 'weather.get_forecast')).and_return(forecast_result)
      allow(connection).to receive(:send_request).with('resources/get', hash_including(name: 'user.profile')).and_return(profile_data)
      
      # Create the client according to the example
      client = MCP::Client.new(url: "http://localhost:3000")
      
      # Connect to the server
      client.connect
      
      # Verify server info
      expect(client.server_info).to eq(server_info)
      
      # List available tools
      tools = client.tools.list
      expect(tools).to eq(tools_list)
      
      # Call a tool
      result = client.tools.call("weather.get_forecast", { location: "San Francisco" })
      expect(result).to eq(forecast_result)
      
      # Get a resource
      profile = client.resources.get("user.profile")
      expect(profile).to eq(profile_data)
      
      # Disconnect
      client.disconnect
      expect(client.connected?).to be(false)
    end
  end
  
  # Test the authenticated example
  describe "Authenticated example" do
    it "creates a server with OAuth authentication" do
      # Mock transport and connection
      transport = double('Transport', connect: nil, disconnect: nil, connected?: true)
      allow(MCP::Protocol).to receive(:create_server).and_return(transport)
      allow(transport).to receive(:set_auth_middleware)
      allow(transport).to receive(:instance_variable_get).with(any_args).and_return(nil)
      
      # Create OAuth provider and permissions
      oauth_provider = MCP::Server::Auth::OAuth.new(
        client_id: 'your-client-id',
        client_secret: 'your-client-secret',
        token_expiry: 3600,
        jwt_secret: 'your-jwt-secret',
        issuer: 'your-server'
      )
      
      permissions = MCP::Server::Auth::Permissions.new
      permissions.add_method('tools/list', ['tools:read'])
      permissions.add_method('tools/call', ['tools:call'])
      
      # Create server with authentication
      server = MCP::Server.new
      server.set_auth_provider(oauth_provider, permissions)
      
      # Define tools
      server.tools.define('example') do |t|
        t.parameter :name, :string
        
        t.execute do |params|
          "Hello, #{params[:name]}!"
        end
      end
      
      # Verify the server has the tool and auth provider
      expect(server.instance_variable_get(:@server).instance_variable_get(:@auth_provider)).to eq(oauth_provider)
      expect(server.instance_variable_get(:@server).instance_variable_get(:@permissions)).to eq(permissions)
      
      tools_manager = server.instance_variable_get(:@server).instance_variable_get(:@tools_manager)
      expect(tools_manager.list.map { |t| t[:name] }).to include('example')
      
      # Verify the transport received the auth middleware
      expect(transport).to have_received(:set_auth_middleware).with(oauth_provider, permissions)
    end
    
    it "creates a client with OAuth authentication" do
      # Mock the OAuth2 client
      oauth_client = double('OAuth2::Client')
      auth_code = double('OAuth2::Strategy::AuthCode')
      allow(OAuth2::Client).to receive(:new).and_return(oauth_client)
      allow(oauth_client).to receive(:auth_code).and_return(auth_code)
      
      # Mock token exchange
      token = double(
        'OAuth2::AccessToken',
        token: 'your-access-token',
        refresh_token: 'refresh-token',
        params: {
          'user_id' => 'user123',
          'scope' => 'tools:read tools:call'
        },
        expired?: false
      )
      
      allow(auth_code).to receive(:get_token).and_return(token)
      
      # Mock the transport and connection
      transport = double('Transport', connect: nil, disconnect: nil, connected?: true, on_event: nil)
      connection = double('Connection')
      
      allow(MCP::Protocol).to receive(:create_transport).and_return(transport)
      allow(transport).to receive(:connect).and_return(connection)
      allow(transport).to receive(:set_auth_token)
      allow(connection).to receive(:initialize_connection).and_return({
        serverInfo: { name: 'Test Server', version: '1.0.0' },
        protocolVersion: MCP::PROTOCOL_VERSION,
        capabilities: {}
      })
      
      allow(connection).to receive(:send_request).and_return({ result: 'Hello, World!' })
      
      # Create the client according to the example
      client = MCP::Client.new(url: "http://localhost:3000/mcp")
      
      # Set up OAuth credentials
      client.set_oauth_credentials(
        client_id: 'your-client-id',
        client_secret: 'your-client-secret',
        site: 'http://localhost:3000',
        authorize_url: '/oauth/authorize',
        token_url: '/oauth/token',
        scopes: ['tools:read', 'tools:call'],
        auto_refresh: true
      )
      
      # Exchange code for token (in the example)
      token = client.exchange_code('authorization_code')
      
      # Connect and call a tool
      client.connect
      result = client.tools.call('example', { name: 'World' })
      
      # Verify the client has the token and made the authenticated request
      expect(client.authenticated?).to be(true)
      expect(transport).to have_received(:set_auth_token).with('your-access-token')
      expect(result).to eq({ result: 'Hello, World!' })
    end
  end
  
  # Test the Rails integration example
  describe "Rails integration example" do
    # We can't fully test Rails integration, but we can verify the code is valid
    it "provides valid Ruby code for Rails integration" do
      # Check the example routes.rb
      routes_rb = File.read(File.join(__dir__, '../../examples/rails_integration/routes.rb'))
      expect(routes_rb).to include('mount MCP::Server::RailsEngine => "/mcp"')
      
      # Check the initializer
      initializer = File.read(File.join(__dir__, '../../examples/rails_integration/ruby_mcp_initializer.rb'))
      
      # Verify it contains the key components
      expect(initializer).to include('MCP.configure do |config|')
      expect(initializer).to include('config.server_transport = :http')
      
      # Verify the server setup
      expect(initializer).to include('MCP::Server.new do |server|')
      expect(initializer).to include('server.tool')
      expect(initializer).to include('server.resource')
    end
  end
end