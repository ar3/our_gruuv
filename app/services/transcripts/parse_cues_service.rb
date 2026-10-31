# frozen_string_literal: true

module Transcripts
  # Parses WEBVTT / SRT / plain speaker lines into cue hashes for debug transcript UI.
  class ParseCuesService
    TIMESTAMP = /
      (?<h>\d{2}):(?<m>\d{2}):(?<s>\d{2})(?:[.,](?<ms>\d{1,3}))?
    /x
    ARROW = /-->/

    def self.call(raw:)
      new(raw: raw).call
    end

    def initialize(raw:)
      @raw = raw.to_s.dup.force_encoding("UTF-8")
                   .encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
    end

    def call
      return [] if @raw.blank?

      if @raw.lstrip.start_with?("WEBVTT") || @raw.match?(/^\d+\s*\n\d{2}:\d{2}:\d{2}[.,]\d{3}\s+-->/m)
        parse_timed_cues
      else
        parse_plain_speaker_lines
      end
    end

    private

    def parse_timed_cues
      cues = []
      blocks = @raw.split(/\n\s*\n+/).map(&:strip).reject(&:blank?)
      blocks.each do |block|
        lines = block.lines.map(&:rstrip)
        next if lines.empty?
        next if lines.first.match?(/\AWEBVTT/i)
        next if lines.first.match?(/\ANOTE\b/i)

        time_idx = lines.index { |line| line.match?(ARROW) }
        next unless time_idx

        timing = lines[time_idx]
        start_label, end_label = timing.split(ARROW, 2).map { |part| part.to_s.strip.split(/\s+/).first }
        text_lines = lines[(time_idx + 1)..] || []
        text_lines = text_lines.reject { |line| line.match?(/\ANOTE\b/i) }
        joined = text_lines.join(" ").squeeze(" ").strip
        next if joined.blank?

        speaker, body = split_speaker(joined)
        meta = NormalizeSpeakerLabel.call(speaker)
        cues << cue_hash(
          index: cues.size + 1,
          start_label: start_label,
          end_label: end_label,
          speaker_label: speaker,
          text: body.presence || joined,
          kind: meta["kind"]
        )
      end
      cues
    end

    def parse_plain_speaker_lines
      cues = []
      @raw.each_line do |line|
        stripped = line.strip
        next if stripped.blank?

        speaker, body = split_speaker(stripped)
        next if body.blank? && speaker == stripped

        meta = NormalizeSpeakerLabel.call(speaker)
        cues << cue_hash(
          index: cues.size + 1,
          start_label: nil,
          end_label: nil,
          speaker_label: speaker,
          text: body.presence || stripped,
          kind: meta["kind"]
        )
      end
      cues
    end

    def split_speaker(text)
      if text =~ /\A([^:]{1,80}):\s*(.*)\z/m
        [$1.strip, $2.strip]
      else
        ["", text.strip]
      end
    end

    def cue_hash(index:, start_label:, end_label:, speaker_label:, text:, kind:)
      {
        "id" => "cue-#{index}",
        "index" => index,
        "start" => start_label,
        "end" => end_label,
        "start_ms" => parse_ms(start_label),
        "end_ms" => parse_ms(end_label),
        "speaker_label" => speaker_label.to_s,
        "text" => text.to_s,
        "kind" => kind
      }
    end

    def parse_ms(label)
      return nil if label.blank?
      return nil unless label =~ TIMESTAMP

      hours = Regexp.last_match[:h].to_i
      minutes = Regexp.last_match[:m].to_i
      seconds = Regexp.last_match[:s].to_i
      ms = (Regexp.last_match[:ms] || "0").ljust(3, "0")[0, 3].to_i
      (((hours * 60) + minutes) * 60 + seconds) * 1000 + ms
    end
  end
end
