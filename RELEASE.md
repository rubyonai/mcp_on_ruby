# Release Process for MCP on Ruby

This document outlines the steps to release a new version of the gem.

## Pre-release Checklist

- [ ] All tests pass: `bundle exec rspec`
- [ ] Code linting passes: `bundle exec rubocop`
- [ ] Documentation is up to date
- [ ] CHANGELOG.md is updated with new version and changes
- [ ] Version number is updated in `lib/mcp_on_ruby/version.rb`
- [ ] Examples are tested and working

## Release Steps

1. **Ensure clean working directory**
   ```bash
   git status
   ```

2. **Run tests**
   ```bash
   bundle exec rspec
   bundle exec rubocop
   ```

3. **Update version** (if not already done)
   ```bash
   # Edit lib/mcp_on_ruby/version.rb
   # Update VERSION constant
   ```

4. **Update CHANGELOG.md**
   - Add release date
   - Ensure all changes are documented
   - Follow Keep a Changelog format

5. **Commit version bump**
   ```bash
   git add -A
   git commit -m "Bump version to v1.0.0"
   ```

6. **Create git tag**
   ```bash
   git tag -a v1.0.0 -m "Release version 1.0.0"
   ```

7. **Build the gem**
   ```bash
   gem build mcp_on_ruby.gemspec
   ```

8. **Test the gem locally**
   ```bash
   gem install ./mcp_on_ruby-1.0.0.gem
   # Create a test Rails app and verify it works
   ```

9. **Push to GitHub**
   ```bash
   git push origin main
   git push origin v1.0.0
   ```

10. **Release to RubyGems**
    ```bash
    gem push mcp_on_ruby-1.0.0.gem
    ```

11. **Create GitHub Release**
    - Go to https://github.com/rubyonai/mcp_on_ruby/releases
    - Click "Draft a new release"
    - Select the tag v1.0.0
    - Title: "v1.0.0 - Production Ready Rails MCP Server"
    - Copy the CHANGELOG entries for this version
    - Publish release

## Post-release

- [ ] Verify gem is available on RubyGems.org
- [ ] Test installation: `gem install mcp_on_ruby`
- [ ] Update any example projects
- [ ] Announce the release (optional)

## Version Numbering

We follow Semantic Versioning (https://semver.org/):
- MAJOR version for incompatible API changes
- MINOR version for backwards-compatible functionality additions  
- PATCH version for backwards-compatible bug fixes