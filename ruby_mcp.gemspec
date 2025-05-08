# frozen_string_literal: true

require_relative 'lib/ruby_mcp/version'

Gem::Specification.new do |spec|
  spec.name = 'mcp_on_ruby'
  spec.version = RubyMCP::VERSION
  spec.authors = ['Nagendra Kamath']
  spec.email = ['your-email@example.com']

  spec.summary = 'Ruby implementation of the Model Context Protocol (MCP)'
  spec.description = 'A Ruby library for building MCP clients and servers that follow the specification.'
  spec.homepage = 'https://github.com/nagstler/mcp_on_ruby'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/nagstler/mcp_on_ruby'
  spec.metadata['changelog_uri'] = 'https://github.com/nagstler/mcp_on_ruby/blob/main/CHANGELOG.md'

  spec.files = Dir.glob('{bin,lib}/**/*') + %w[LICENSE.txt README.md CHANGELOG.md]
  spec.bindir = 'bin'
  spec.executables = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'concurrent-ruby', '~> 1.2'
  spec.add_dependency 'faye-websocket', '~> 0.11'
  spec.add_dependency 'json-schema', '~> 4.0'
  spec.add_dependency 'jwt', '~> 2.7'
  spec.add_dependency 'oauth2', '~> 2.0'
  spec.add_dependency 'rack', '~> 3.0'
  spec.add_dependency 'securerandom', '~> 0.2'

  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'rubocop', '~> 1.50'
  spec.add_development_dependency 'simplecov', '~> 0.22'
  spec.add_development_dependency 'webmock', '~> 3.18'
end