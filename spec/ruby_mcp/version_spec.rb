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

    it 'is referenced in the gemspec' do
      gemspec_path = File.expand_path('../../ruby_mcp.gemspec', __dir__)
      gemspec_content = File.read(gemspec_path)
      
      # Check that gemspec uses the VERSION constant
      expect(gemspec_content).to include('spec.version = RubyMCP::VERSION')
    end
  end
end
