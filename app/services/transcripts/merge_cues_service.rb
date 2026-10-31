# frozen_string_literal: true

module Transcripts
  # Groups consecutive VTT/SRT caption blocks into "moment" cues for first-pass /
  # Step 2 review. Deterministic: same speaker + short time gap (or untimed lines).
  # Does not call an LLM — caption atoms remain available via source_cue_ids.
  class MergeCuesService
    # Max silence between same-speaker blocks that still count as one moment.
    MAX_GAP_MS = 3_000

    def self.call(cues:)
      new(cues: cues).call
    end

    def initialize(cues:)
      @cues = Array(cues).map { |cue| cue.with_indifferent_access }
    end

    def call
      return [] if @cues.empty?

      groups = []
      current = [@cues.first]

      @cues.drop(1).each do |cue|
        if should_merge?(current.last, cue)
          current << cue
        else
          groups << current
          current = [cue]
        end
      end
      groups << current

      groups.map.with_index(1) { |atoms, index| merge_group(atoms, index) }
    end

    private

    def should_merge?(previous, nxt)
      return false if previous[:kind].to_s != nxt[:kind].to_s
      return false unless same_speaker?(previous, nxt)

      # Songs / shared audio: keep one row for the whole stretch of the same sharer.
      return true if previous[:kind].to_s == "audio_share"

      prev_end = previous[:end_ms]
      next_start = nxt[:start_ms]

      # Plain / untimed lines: consecutive same-speaker lines are one moment.
      return true if prev_end.blank? || next_start.blank?

      gap = next_start.to_i - prev_end.to_i
      return false if gap.negative? && !overlapping?(previous, nxt)
      return true if gap <= MAX_GAP_MS

      # Slightly longer gap still merges when the prior caption looks unfinished.
      gap <= MAX_GAP_MS * 2 && unfinished?(previous[:text])
    end

    def same_speaker?(a, b)
      a[:speaker_label].to_s.strip == b[:speaker_label].to_s.strip &&
        a[:speaker_label].to_s.strip.present?
    end

    def overlapping?(previous, nxt)
      prev_start = previous[:start_ms]
      prev_end = previous[:end_ms]
      next_start = nxt[:start_ms]
      next_end = nxt[:end_ms]
      return false if [prev_start, prev_end, next_start, next_end].any?(&:blank?)

      next_start.to_i <= prev_end.to_i && next_end.to_i >= prev_start.to_i
    end

    def unfinished?(text)
      stripped = text.to_s.strip
      return false if stripped.blank?
      return true if stripped.match?(/[,:;…]|\.\.\.\z/)
      return true unless stripped.match?(/[.!?]"?\z/)

      false
    end

    def merge_group(atoms, index)
      first = atoms.first
      last = atoms.last
      texts = atoms.map { |atom| atom[:text].to_s.strip }.reject(&:blank?)
      joined = texts.join(" ").squeeze(" ").strip

      {
        "id" => "cue-#{index}",
        "index" => index,
        "start" => first[:start],
        "end" => last[:end],
        "start_ms" => first[:start_ms],
        "end_ms" => last[:end_ms],
        "speaker_label" => first[:speaker_label].to_s,
        "text" => joined,
        "kind" => first[:kind].to_s,
        "source_cue_ids" => atoms.map { |atom| atom[:id].to_s },
        "source_block_count" => atoms.size,
        "merged" => atoms.size > 1
      }
    end
  end
end
