# frozen_string_literal: true

module Zoom
  # Downloads a Zoom cloud recording transcript and normalizes to plaintext.
  class DownloadTranscriptService
    def self.call(teammate:, download_url:)
      new(teammate: teammate, download_url: download_url).call
    end

    def initialize(teammate:, download_url:)
      @teammate = teammate
      @download_url = download_url.to_s
      @client = OauthClient.new(teammate)
    end

    def call
      raise ArgumentError, "download_url is required" if @download_url.blank?
      raise OauthClient::ApiError, "Zoom is not connected." unless @client.authenticated?

      body = @client.get_body(@download_url).to_s.dup.force_encoding("UTF-8")
      body = body.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
      plaintext = normalize(body).strip
      raise OauthClient::ApiError, "Transcript file was empty." if plaintext.blank?

      plaintext
    end

    private

    def normalize(raw)
      if raw.lstrip.start_with?("WEBVTT") || raw.match?(/-->/)
        strip_webvtt(raw)
      else
        raw
      end
    end

    def strip_webvtt(text)
      text.lines.reject { |l| l =~ /\AWEBVTT/i || l =~ /\ANOTE\b/i || l =~ /-->/ || l.strip.empty? }
          .map { |l| l.sub(/\A.*?> /, "") }
          .join
          .squeeze("\n")
    end
  end
end
