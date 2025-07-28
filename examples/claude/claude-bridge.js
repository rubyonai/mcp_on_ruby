#!/usr/bin/env node

const http = require('http');
const { stdin, stdout, stderr } = process;

// MCP server configuration
const RAILS_HOST = 'localhost';
const RAILS_PORT = 3001;
const RAILS_PATH = '/mcp';
const AUTH_TOKEN = 'test-db-inspector-token';

// Set up stdio
stdin.setEncoding('utf8');
process.on('SIGTERM', () => process.exit(0));
process.on('SIGINT', () => process.exit(0));

let buffer = '';

stdin.on('data', (chunk) => {
  buffer += chunk;
  
  // Process complete JSON-RPC messages
  const lines = buffer.split('\n');
  buffer = lines.pop() || ''; // Keep incomplete line
  
  for (const line of lines) {
    if (line.trim()) {
      handleRequest(line.trim());
    }
  }
});

stdin.on('end', () => {
  if (buffer.trim()) {
    handleRequest(buffer.trim());
  }
});

async function handleRequest(requestLine) {
  let requestId = 1; // Default ID
  
  try {
    // Parse and validate JSON-RPC request
    const request = JSON.parse(requestLine);
    requestId = request.id || 1; // Use request ID or default to 1
    
    // Forward to Rails MCP server
    const response = await forwardToRails(requestLine);
    
    // Parse response to ensure it has correct ID
    try {
      const parsedResponse = JSON.parse(response);
      if (parsedResponse.id === null || parsedResponse.id === undefined) {
        parsedResponse.id = requestId;
      }
      stdout.write(JSON.stringify(parsedResponse) + '\n');
    } catch {
      // If response is not valid JSON, create proper response
      const successResponse = {
        jsonrpc: "2.0",
        id: requestId,
        result: { message: response }
      };
      stdout.write(JSON.stringify(successResponse) + '\n');
    }
    
  } catch (error) {
    // Send JSON-RPC error response with proper ID
    const errorResponse = {
      jsonrpc: "2.0",
      id: requestId,
      error: {
        code: -32700,
        message: "Parse error",
        data: error.message
      }
    };
    stdout.write(JSON.stringify(errorResponse) + '\n');
  }
}

function forwardToRails(requestData) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: RAILS_HOST,
      port: RAILS_PORT,
      path: RAILS_PATH,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${AUTH_TOKEN}`,
        'Content-Length': Buffer.byteLength(requestData)
      },
      timeout: 30000
    };

    const req = http.request(options, (res) => {
      let responseData = '';
      
      res.on('data', (chunk) => {
        responseData += chunk;
      });
      
      res.on('end', () => {
        resolve(responseData);
      });
    });

    req.on('error', (error) => {
      // Return error as string to be wrapped in proper JSON-RPC format
      resolve(`Connection failed: ${error.message}`);
    });

    req.on('timeout', () => {
      req.destroy();
      resolve('Request timeout');
    });

    req.write(requestData);
    req.end();
  });
}