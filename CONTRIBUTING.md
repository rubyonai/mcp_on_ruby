# Contributing to RubyMCP

Thank you for considering contributing to RubyMCP! This document outlines the process for contributing to the project.

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## How Can I Contribute?

### Reporting Bugs

This section guides you through submitting a bug report for RubyMCP.

Before creating bug reports, please check [the issue list](https://github.com/nagstler/mcp_on_ruby/issues) to avoid duplicating an existing report. When you create a bug report, include as many details as possible:

* **Use a clear and descriptive title**
* **Describe the exact steps to reproduce the bug**
* **Provide specific examples**
* **Describe the behavior you observed**
* **Explain the behavior you expected**
* **Include screenshots or animated GIFs** if possible
* **Include details about your configuration and environment**

### Suggesting Enhancements

This section guides you through submitting an enhancement suggestion for RubyMCP.

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:

* **Use a clear and descriptive title**
* **Provide a detailed description of the suggested enhancement**
* **Explain why this enhancement would be useful**
* **Specify which version you're using**
* **Specify the name and version of the OS you're using**

### Pull Requests

* Fill in the required template
* Follow the Ruby style guide
* Include tests for new features
* Document new code based on the rest of the codebase
* End all files with a newline

## Development Process

### Setting Up Development Environment

```bash
# Fork and clone the repository
git clone https://github.com/yourusername/ruby_mcp.git
cd ruby_mcp

# Install dependencies
bundle install

# Run tests
bundle exec rspec


### Testing

Write tests for all new features
Ensure all tests pass before submitting a pull request
Run the full test suite locally before submission

```bash
bundle exec rspec
```

### Style Guidelines

Code should follow the Ruby style guide
Run RuboCop to check your code style

```bash
bundle exec rubocop
```

### Release Process

RubyMCP follows Semantic Versioning.

- MAJOR version for incompatible API changes
- MINOR version for backward-compatible functionality additions
- PATCH version for backward-compatible bug fixes

### First-time Contributors
If you're new to the project, look for issues labeled with good first issue which are ideal starting points for newcomers.

### License
By contributing to RubyMCP, you agree that your contributions will be licensed under the project's MIT License.