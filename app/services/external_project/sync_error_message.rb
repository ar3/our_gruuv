# frozen_string_literal: true

module ExternalProject
  class SyncErrorMessage
    def self.for(result, source)
      error_type = result[:error_type] || "unknown_error"
      base_message = result[:error] || "Unknown error occurred"

      case error_type
      when "token_expired"
        source_name = source == "asana" ? "Asana" : source.to_s.titleize
        "Your #{source_name} token has expired. Please reconnect your account to sync the project."
      when "permission_denied"
        "You do not have permission to access this project. #{base_message}"
      when "not_found", "project_not_found"
        "Project not found. Please verify the project URL is correct."
      when "not_authenticated"
        source_name = source == "asana" ? "Asana" : source.to_s.titleize
        "You are not authenticated with #{source_name}. Please connect your account first."
      when "network_error"
        "Network error: #{base_message}. Please try again later."
      when "api_error"
        "API error: #{base_message}. Please try again later."
      when "sync_timeout"
        "Sync timed out while talking to #{source == 'asana' ? 'Asana' : source.to_s.titleize}. Please try again."
      when "sync_incomplete", "sync_skipped", "exception"
        base_message.presence || "Sync failed. Please try again."
      else
        "Failed to sync project: #{base_message}"
      end
    end
  end
end
