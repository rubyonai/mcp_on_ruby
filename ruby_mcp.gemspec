# frozen_string_literal: true

require_relative 'lib/ruby_mcp/version'

Gem::Specification.new do |spec|
  spec.name = 'mcp_on_ruby'
  spec.version = RubyMCP::VERSION
  spec.authors = ['Nagendra Dhanakeerthi']
  spec.email = ['nagendra.dhanakeerthi@gmail.com']

  spec.summary = 'Ruby implementation of the Model Context Protocol (MCP)'
  spec.description = <<~DESC.strip
    A comprehensive Ruby gem for implementing Model Context Protocol servers
    to standardize interactions with AI language models
  DESC

  spec.homepage = 'https://github.com/nagstler/mcp_on_ruby'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 2.6.0'

  # For public gems on RubyGems.org
  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Dependencies
  spec.add_dependency 'faraday', '~> 2.7'
  spec.add_dependency 'faraday-net_http', '~> 3.0'
  spec.add_dependency 'jwt', '~> 2.7'
  # spec.add_dependency "json-schema", "~> 4.0"
  spec.add_dependency 'concurrent-ruby', '~> 1.2'
  spec.add_dependency 'dry-schema', '~> 1.13'
  spec.add_dependency 'webrick', '~> 1.7'

  spec.add_dependency 'rack', '~> 2.2'
  spec.add_dependency 'rack-cors', '~> 1.1'

  # Development dependencies
  spec.add_development_dependency 'vcr', '~> 6.1'
  spec.add_development_dependency 'webmock', '~> 3.18'

  spec.add_development_dependency 'codecov', '~> 0.6.0'
  spec.add_development_dependency 'rack-test', '~> 2.1'
  spec.add_development_dependency 'simplecov', '~> 0.21.2'
  spec.add_development_dependency 'simplecov-cobertura', '~> 2.1'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    # Use Dir.glob for files that actually exist, rather than git ls-files
    Dir.glob('lib/**/*') +
      Dir.glob('*.{md,txt}') +
      %w[LICENSE.txt README.md]
  end

  spec.files.reject! do |f|
    f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
  end

  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
