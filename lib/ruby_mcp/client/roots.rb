# frozen_string_literal: true

module MCP
  module Client
    # Client-side roots functionality
    module Roots
      # Register the roots list handler with the server
      # @param roots [Array<Hash>] The roots to register
      def set_roots(roots)
        @roots = roots
        
        # Register event handlers
        on_event(:roots_list_changed) do
          handle_roots_list_changed
        end
        
        # Send the roots list to the server if already connected
        send_roots_list if connected?
      end
      
      # Send the roots list to the server
      def send_roots_list
        ensure_connected
        
        # Convert to MCP format
        roots_list = @roots.map do |root|
          {
            name: root[:name],
            description: root[:description] || "",
            allowWrites: root[:allow_writes] || false
          }
        end
        
        # Send the roots list notification
        request = MCP::Protocol::JsonRPC.notification('roots/list', {
          roots: roots_list
        })
        
        @connection.send_notification(request)
      end
      
      private
      
      # Handle roots/list_changed notification
      def handle_roots_list_changed
        # Send the updated roots list
        send_roots_list
      end
    end
  end
end