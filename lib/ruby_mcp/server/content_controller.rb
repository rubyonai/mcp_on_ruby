# frozen_string_literal: true
require "base64"

module RubyMCP
  module Server
    class ContentController < BaseController
      def create
        context_id = params[:context_id]
        content_id = params[:id] || "cnt_#{SecureRandom.hex(10)}"
        content_type = params[:type] || "file"
        
        begin
          # Get context to ensure it exists
          storage.get_context(context_id)
          
          # Handle file data (base64 encoded)
          if params[:file_data]
            data = {
              filename: params[:filename],
              content_type: params[:content_type] || "application/octet-stream",
              data: Base64.strict_decode64(params[:file_data])
            }
          else
            data = params[:data] || {}
          end
          
          # Store the content
          storage.add_content(context_id, content_id, data)
          
          created({
            id: content_id,
            context_id: context_id,
            type: content_type
          })
        rescue RubyMCP::Errors::ContextError => e
          not_found(e.message)
        rescue ArgumentError => e
          # Handle base64 decoding errors
          bad_request("Invalid file_data: #{e.message}")
        end
      end
      
      def show
        context_id = params[:context_id]
        content_id = params[:id]
        
        begin
          content = storage.get_content(context_id, content_id)
          
          if content[:filename] && content[:data]
            # Send file response
            headers = {
              "Content-Type" => content[:content_type],
              "Content-Disposition" => "attachment; filename=\"#{content[:filename]}\""
            }
            [200, headers, [content[:data]]]
          else
            # Send JSON response
            ok(content)
          end
        rescue RubyMCP::Errors::ContextError, RubyMCP::Errors::ContentError => e
          not_found(e.message)
        end
      end
    end
  end
end