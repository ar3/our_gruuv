# frozen_string_literal: true

module Transcripts
  # Normalizes transcript uploads (VTT/SRT/plain/JSON-ish) to a single plain string for LLM input.
  class PlaintextFromBlobService
    def self.call(blob:)
      new(blob: blob).call
    end

    def initialize(blob:)
      @blob = blob
    end

    def call
      raw = @blob.download.force_encoding('UTF-8')
      raw = raw.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
      name = @blob.filename.to_s.downcase

      if name.end_with?('.vtt') || raw.lstrip.start_with?('WEBVTT')
        strip_webvtt(raw)
      elsif name.end_with?('.srt') || raw.match?(/\d+\s*\n\d{2}:\d{2}:\d{2}/)
        strip_srt(raw)
      elsif name.end_with?('.json')
        raw
      else
        raw
      end
    end

    private

    def strip_webvtt(text)
      text.lines.reject { |l| l =~ /\AWEBVTT/i || l =~ /\ANOTE\b/i || l =~ /-->/ || l.strip.empty? }
            .map { |l| l.sub(/\A.*?> /, '') }
            .join
            .squeeze("\n")
    end

    def strip_srt(text)
      text.gsub(/^\d+\s*$/m, '').gsub(/^\d{2}:\d{2}:\d{2},\d{3}\s+-->\s+\d{2}:\d{2}:\d{2},\d{3}.*$/m, "\n")
          .squeeze("\n")
    end
  end
end
