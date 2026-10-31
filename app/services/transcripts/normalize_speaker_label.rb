# frozen_string_literal: true

module Transcripts
  # Cleans Zoom/Meet VTT speaker labels for teammate matching.
  # Patterns from All-Hands fixtures: "Audio shared by X", "polly (she/her)", "Name (he/him)".
  class NormalizeSpeakerLabel
    AUDIO_SHARED = /\AAudio shared by\s+/i
    PRONOUN_SUFFIX = /\s*\((?:he|she|they)(?:\s*\/\s*(?:him|her|them))?\)\s*\z/i

    def self.call(label)
      new(label).call
    end

    def initialize(label)
      @raw = label.to_s.strip
    end

    def call
      working = @raw
      kind = "speech"
      if working.match?(AUDIO_SHARED)
        kind = "audio_share"
        working = working.sub(AUDIO_SHARED, "")
      end
      working = working.sub(PRONOUN_SUFFIX, "").strip
      {
        "raw" => @raw,
        "normalized" => working.presence || @raw,
        "kind" => kind
      }
    end
  end
end
