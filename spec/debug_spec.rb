# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Module Debug' do
  it 'checks the loaded modules' do
    puts "Defined constants: #{Object.constants.grep(/MCP/).join(', ')}"
    puts "MCP included modules: #{MCP.included_modules.map(&:to_s).join(', ')}"
    puts "MCP singleton methods: #{MCP.singleton_methods.map(&:to_s).join(', ')}"
    puts "MCP constants: #{MCP.constants.join(', ')}"

    # Check if specific modules are defined
    puts "MCP::Client defined? #{defined?(MCP::Client) != nil}"
    puts "MCP::Server defined? #{defined?(MCP::Server) != nil}"
    puts "MCP::Protocol defined? #{defined?(MCP::Protocol) != nil}"

    # Examine the OAuth2::AccessToken class
    puts "\n=== OAuth2::AccessToken Class Analysis ==="
    if defined?(OAuth2::AccessToken)
      puts "OAuth2::AccessToken defined? true"
      puts "Ancestor chain: #{OAuth2::AccessToken.ancestors.map(&:to_s).join(', ')}"
      puts "Instance methods: #{OAuth2::AccessToken.instance_methods(false).sort.join(', ')}"
      puts "Attributes: #{OAuth2::AccessToken.instance_variables.sort.join(', ')}"
      
      # Create a test instance of OAuth2::AccessToken
      puts "\nTesting OAuth2::AccessToken directly:"
      begin
        client = OAuth2::Client.new('test_client', 'test_secret')
        
        # Standard way to use params in OAuth2::AccessToken
        token = OAuth2::AccessToken.new(
          client,
          'test_token',
          refresh_token: 'test_refresh',
          expires_in: 3600,
          params: {'user_id' => '123', 'scope' => 'read write'}
        )
        
        puts "Token class: #{token.class}"
        puts "Token methods: #{token.methods.grep(/param/).sort.join(', ')}"
        puts "Token instance variables: #{token.instance_variables.sort.join(', ')}"
        puts "Token.params class: #{token.params.class}"
        puts "Token.params: #{token.params.inspect}"
        puts "Token.params['user_id']: #{token.params['user_id'].inspect}"
        puts "Token.params['scope']: #{token.params['scope'].inspect}"
        
        # Create another token with different parameter structure
        token2 = OAuth2::AccessToken.new(
          client,
          'test_token',
          {
            refresh_token: 'test_refresh',
            expires_in: 3600,
            params: {'user_id' => '456', 'scope' => 'read'}
          }
        )
        
        puts "\nToken2 class: #{token2.class}"
        puts "Token2.params: #{token2.params.inspect}"
        puts "Token2.params['user_id']: #{token2.params['user_id'].inspect}"
        
        # Create a token with a hash as a parameter
        token3 = OAuth2::AccessToken.new(
          client,
          'test_token',
          refresh_token: 'test_refresh',
          expires_in: 3600
        )
        token3.instance_variable_set(:@params, {'user_id' => '789', 'scope' => 'admin'})
        
        puts "\nToken3 with directly set @params:"
        puts "Token3.params: #{token3.params.inspect}"
        puts "Token3.params['user_id']: #{token3.params['user_id'].inspect}"
      rescue => e
        puts "Error testing OAuth2::AccessToken: #{e.message}"
        puts e.backtrace.join("\n")
      end
    end
    
    # Check Auth module implementation details
    puts "\n=== Auth Module Implementation ==="
    if defined?(MCP::Server::Auth)
      puts "MCP::Server::Auth defined? true"
      puts "MCP::Server::Auth constants: #{MCP::Server::Auth.constants.join(', ')}"
      
      if defined?(MCP::Server::Auth::OAuth)
        oauth_class = MCP::Server::Auth::OAuth
        puts "OAuth class: #{oauth_class}"
        puts "OAuth class file location: #{oauth_class.instance_method(:initialize).source_location.first rescue 'unknown'}"
        
        # Test the OAuth implementation with a fixed test
        puts "\nTesting OAuth implementation with test values:"
        begin
          options = {
            client_id: 'test_client',
            client_secret: 'test_secret',
            token_expiry: 3600,
            jwt_secret: 'test_jwt_secret',
            issuer: 'test_issuer',
            scopes: ['tools:read', 'tools:call']
          }
          
          oauth = oauth_class.new(options)
          
          # Create a super simple token with direct params
          class SimpleToken
            attr_reader :params
            def initialize(params = {})
              @params = params
            end
          end
          
          # Test with our simple token
          simple_token = SimpleToken.new({'user_id' => '123', 'scope' => 'tools:read'})
          jwt = oauth.create_jwt(simple_token)
          decoded = JWT.decode(jwt, 'test_jwt_secret', true, { algorithm: 'HS256' })
          puts "Decoded JWT (simple token): #{decoded.first.inspect}"
          puts "JWT 'sub' field (simple token): #{decoded.first['sub'].inspect}"
          
          # Now test the OAuth token creation
          params = {'user_id' => '123', 'scope' => 'tools:read'}
          token = oauth.create_token(params)
          puts "\nCreated token with params: #{params.inspect}"
          puts "Token class: #{token.class}"
          puts "Token params class: #{token.params.class}"
          puts "Token params: #{token.params.inspect}"
          puts "Token params keys: #{token.params.keys.inspect}"
          puts "Token params['user_id']: #{token.params['user_id'].inspect}"
          
          # Now check how our own fixed spec is accessing the token
          file = File.read('/Users/nagendra/OpenSource/mcp_on_ruby/spec/unit/server/fixed/auth/oauth_fixed_spec.rb')
          spec_lines = file.lines.select { |line| line.include?("token.params") }
          puts "\nFixed spec token param access:"
          spec_lines.each_with_index do |line, idx|
            puts "  #{idx+1}. #{line.strip}"
          end
        rescue => e
          puts "Error testing OAuth: #{e.message}"
          puts e.backtrace.join("\n")
        end
      end
    end
    
    expect(1).to eq(1)
  end
end