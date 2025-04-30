# Changelog

## [0.3.0] - 2023-05-01

### Added
- ActiveRecord storage backend for database persistence
- Support for Rails integration with ActiveRecord storage
- Auto-creation of database tables with configurable prefixes
- Proper handling of different data types (text, binary, JSON)
- Symbolization of hash keys for consistent API
- Comprehensive test suite for ActiveRecord storage

### Changed
- Enhanced `StorageFactory` to support ActiveRecord backend
- Updated configuration system with ActiveRecord options
- Improved documentation with ActiveRecord storage examples

## [0.2.0] - 2025-04-21

### Added
- Redis storage backend with comprehensive test coverage
- Configurable TTL and namespace support for Redis keys
- Rails integration with Redis storage examples
- Wiki documentation for Redis storage setup and usage

### Changed
- Enhanced storage factory to support different backend types
- Improved configuration API for more intuitive setup
- Updated README with Redis storage documentation

## [0.1.0] - 2025-04-18

Initial release of version 0.1.0 of the Ruby Gem. 

### Added
- Core MCP implementation with Rack server
- Provider support for OpenAI and Anthropic
- In-memory storage backend
- Context, message, and content management
- Basic authentication support
- Comprehensive test suite