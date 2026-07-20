# frozen_string_literal: true

module GoogleMeet
  # Downloads Meet transcript Docs content as plaintext via Drive export.
  class DownloadTranscriptService
    def self.call(teammate:, document_id:)
      new(teammate: teammate, document_id: document_id).call
    end

    def initialize(teammate:, document_id:)
      @teammate = teammate
      @document_id = document_id.to_s
      @client = OauthClient.new(teammate)
    end

    def call
      raise ArgumentError, "document_id is required" if @document_id.blank?
      raise OauthClient::ApiError, "Google Meet is not connected." unless @client.authenticated?

      body = @client.get_body(
        "https://www.googleapis.com/drive/v3/files/#{CGI.escape(@document_id)}/export",
        params: { mimeType: "text/plain" }
      )
      plaintext = body.to_s.strip
      raise OauthClient::ApiError, "Transcript file was empty." if plaintext.blank?

      plaintext
    end
  end
end
