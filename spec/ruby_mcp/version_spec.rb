# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyMCP do
  describe 'VERSION' do
    it 'has a version number' do
      expect(RubyMCP::VERSION).not_to be_nil
    end

    it 'is a string' do
      expect(RubyMCP::VERSION).to be_a(String)
    end

    it 'follows semantic versioning format' do
      expect(RubyMCP::VERSION).to match(/^\d+\.\d+\.\d+$/)
    end

    it 'matches the version in the gemspec' do
      gemspec_path = File.expand_path('../../ruby_mcp.gemspec', __dir__)
      gemspec_content = File.read(gemspec_path)
      
      # Extract version from gemspec
      gemspec_version = gemspec_content.match(/spec\.version\s*=\s*["'](.+?)["']/)[1]
      
      expect(RubyMCP::VERSION).to eq(gemspec_version)
    end
  end
end
