# Fixing MCP on Ruby Tests

This guide provides instructions for fixing the remaining tests in the MCP on Ruby project.

## Running Fixed Tests

To run only the fixed tests (which are known to pass), use:

```bash
./run_fixed_tests.sh
```

This will run all tests in the fixed directories, avoiding the problematic tests.

## Approach for Fixing Tests

For each test file that needs fixing:

1. Create a new file in a "fixed" subdirectory:
   ```
   spec/unit/module/fixed/test_spec.rb
   ```

2. Use the following pattern:

   ```ruby
   # frozen_string_literal: true

   require 'spec_helper'

   RSpec.describe 'MCP::Module::Class' do
     let(:class_reference) { MCP::Module::Class }
     
     # Set up any necessary mocks
     before do
       # Stub dependencies
     end
     
     # Test methods and behaviors
     describe '#method' do
       it 'does something' do
         # Test code
       end
     end
   end
   ```

3. Once the new test file is created and passing, add it to the pattern in `.rspec_fixed`.

## Key Principles

1. **Use String Descriptions**: Use string descriptions for RSpec describe blocks to avoid constant resolution issues.
2. **Use Let Statements**: Define module/class references with let statements.
3. **Stub Dependencies**: Properly stub dependencies to isolate tests.
4. **Match Implementation**: Make sure tests match the actual implementation.
5. **Add to Fixed Tests**: Once fixed, add the test to the fixed tests pattern.

## Core Components to Fix First

Focus on fixing tests in this order:

1. ✅ Protocol layer (JSON-RPC, Connection, Transport)
2. ✅ Client
3. Server components:
   - ✅ Tools
   - ✅ Resources
   - Prompts
   - Roots
4. Authentication
5. Integration tests

## Adding Fixed Tests

To add a newly fixed test to the run script:

1. Update the pattern in `.rspec_fixed`:

   ```
   --pattern "spec/unit/protocol/fixed/**/*_spec.rb,spec/unit/client/fixed/**/*_spec.rb,spec/unit/server/fixed/**/*_spec.rb,spec/debug_spec.rb"
   ```

## Verifying Progress

To check the coverage of the fixed tests, run:

```bash
./run_fixed_tests.sh
```

The coverage report will show what percentage of the codebase is being tested by the fixed tests.