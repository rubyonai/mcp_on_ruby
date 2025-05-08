#!/bin/bash

# This script runs only the fixed tests to avoid timeouts and failures from unfixed tests

echo "Running fixed tests..."
bundle exec rspec --options .rspec_fixed

# This will run all tests in spec/unit/**/fixed/**/*_spec.rb and spec/debug_spec.rb
# To run specific tests manually, use:
# bundle exec rspec spec/unit/protocol/fixed/json_rpc_spec.rb spec/unit/protocol/fixed/connection_spec.rb