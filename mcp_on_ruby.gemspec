# frozen_string_literal: true

require_relative 'lib/mcp_on_ruby/version'

Gem::Specification.new do |spec|
  spec.name = 'mcp_on_ruby'
  spec.version = McpOnRuby::VERSION
  spec.authors = ['Nagendra Dhanakeerthi']
  spec.email = ['nagendra.dhanakeerthi@gmail.com']

  spec.summary = 'Production-ready MCP server for Rails applications'
  spec.description = 'A comprehensive Ruby library for building Model Context Protocol (MCP) servers in Rails applications, featuring tools, resources, authentication, and real-time capabilities.'
  spec.homepage = 'https://github.com/rubyonai/mcp_on_ruby'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/rubyonai/mcp_on_ruby'
  spec.metadata['changelog_uri'] = 'https://github.com/rubyonai/mcp_on_ruby/blob/main/CHANGELOG.md'

  spec.files = Dir.glob('{bin,lib,examples,docs}/**/*') + %w[LICENSE.txt README.md CHANGELOG.md CODE_OF_CONDUCT.md CONTRIBUTING.md]
  spec.bindir = 'bin'
  spec.executables = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'json-schema', '~> 3.0'
  spec.add_dependency 'rack', '~> 2.2'
  spec.add_dependency 'webrick', '~> 1.7'

  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'rubocop', '~> 1.50'
  spec.add_development_dependency 'simplecov', '~> 0.22'
  spec.add_development_dependency 'webmock', '~> 3.18'
  spec.add_development_dependency 'rack-test', '~> 2.1'
end