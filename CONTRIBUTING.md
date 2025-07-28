# Contributing to MCP on Ruby

We love your input! We want to make contributing to this project as easy and transparent as possible, whether it's:

- Reporting a bug
- Discussing the current state of the code
- Submitting a fix
- Proposing new features
- Becoming a maintainer

## Development Process

We use GitHub to host code, to track issues and feature requests, as well as accept pull requests.

## Pull Requests

1. Fork the repo and create your branch from `main`.
2. If you've added code that should be tested, add tests.
3. If you've changed APIs, update the documentation.
4. Ensure the test suite passes.
5. Make sure your code lints.
6. Issue that pull request!

## Development Setup

```bash
# Clone your fork
git clone https://github.com/nagstler/mcp_on_ruby.git
cd mcp_on_ruby

# Install dependencies
bundle install

# Run the generators to test Rails integration
mkdir test_app && cd test_app
rails new . --skip-git
echo "gem 'mcp_on_ruby', path: '..' " >> Gemfile
bundle install
rails generate mcp_on_ruby:install

# Test the gem
cd .. && ruby -e "require './lib/mcp_on_ruby'; puts 'Gem loads successfully'"
```

## Code Style

- Follow standard Ruby conventions
- Use meaningful variable and method names
- Add documentation for public APIs
- Keep methods focused and small

## Testing

Currently, we use manual testing and examples. In the future, we plan to add:
- RSpec test suite
- Integration tests with Rails
- CI/CD pipeline

## Bug Reports

We use GitHub issues to track public bugs. Report a bug by [opening a new issue](https://github.com/nagstler/mcp_on_ruby/issues).

**Great Bug Reports** tend to have:

- A quick summary and/or background
- Steps to reproduce
  - Be specific!
  - Give sample code if you can
- What you expected would happen
- What actually happens
- Notes (possibly including why you think this might be happening, or stuff you tried that didn't work)

## Feature Requests

We use GitHub issues to track feature requests. Propose a feature by [opening a new issue](https://github.com/nagstler/mcp_on_ruby/issues).

**Great Feature Requests** include:

- Clear use case description
- Why this feature would be useful
- Proposed API or implementation approach
- Examples of how it would be used

## License

By contributing, you agree that your contributions will be licensed under the same MIT License that covers the project.