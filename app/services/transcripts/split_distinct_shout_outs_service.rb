# frozen_string_literal: true

module Transcripts
  # After same-speaker caption merge, split a long turn into distinct shout-out
  # moments when the speaker clearly pivots ("Couple more… which is Amy").
  # Deterministic — keeps transcript text verbatim; no LLM.
  class SplitDistinctShoutOutsService
    # Only fire after the turn has already said something (avoid splitting the opener).
    MIN_LEADING_CHARS = 40
    # "Couple more… Well… which is Amy" is one pivot — keep the earliest marker in a cluster.
    MARKER_CLUSTER_MS = 120

    MARKERS = [
      /\bCouple more\b/i,
      /\bOne more\b/i,
      /\bWell,?\s+let me(?:\s+\w+){0,6}\s+go to\b/i,
      /\bLet me(?:\s+\w+){0,4}\s+go to the one\b/i,
      /\bNext up\b/i,
      /\bMoving on[,.]?\s+(?:to|I)\b/i,
      /\bAlright,?\s+(?:one more|another|a few more)\b/i,
      /\bAnd then,?\s+(?:for|I want to shout|shout out)\b/i,
      /\bwhich is [A-Z][a-zA-Z'-]{1,30}\b/
    ].freeze

    def self.call(cues:)
      new(cues: cues).call
    end

    def initialize(cues:)
      @cues = Array(cues).map { |cue| cue.with_indifferent_access }
    end

    def call
      expanded = []
      @cues.each do |cue|
        segments = segments_for(cue)
        if segments.size <= 1
          expanded << stringify(cue)
          next
        end

        segments.each do |segment|
          expanded << stringify(cue).merge(
            "text" => segment,
            "merged" => true,
            "split_from_cue_id" => cue[:id].to_s,
            "source_block_count" => cue[:source_block_count].presence || 1
          )
        end
      end

      expanded.map.with_index(1) do |cue, index|
        cue.merge("id" => "cue-#{index}", "index" => index)
      end
    end

    def self.split_text(text)
      new(cues: []).send(:split_text, text)
    end

    private

    def segments_for(cue)
      return [cue[:text].to_s] if cue[:kind].to_s == "audio_share"

      split_text(cue[:text].to_s)
    end

    def split_text(text)
      return [text] if text.blank?

      starts = [0]
      MARKERS.each do |pattern|
        text.to_enum(:scan, pattern).each do
          idx = Regexp.last_match.begin(0)
          starts << idx if idx >= MIN_LEADING_CHARS
        end
      end
      starts = collapse_marker_clusters(starts.uniq.sort)
      return [text] if starts.size < 2

      starts.each_with_index.filter_map do |start_idx, i|
        end_idx = i + 1 < starts.size ? starts[i + 1] : text.length
        segment = text[start_idx...end_idx].to_s.strip
        segment.presence
      end
    end

    def collapse_marker_clusters(starts)
      clustered = []
      starts.each do |idx|
        next if idx.zero?
        next if clustered.any? && (idx - clustered.last) < MARKER_CLUSTER_MS

        clustered << idx
      end
      [0] + clustered
    end

    def stringify(cue)
      cue.to_h.stringify_keys
    end
  end
end
