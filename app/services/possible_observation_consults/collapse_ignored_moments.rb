# frozen_string_literal: true

module PossibleObservationConsults
  # After first pass: consecutive ignore cues from the same speaker are noise —
  # collapse them into one Step 2 row. OGO-worthy cues stay separate moments.
  class CollapseIgnoredMoments
    def self.call(cues:, annotations:)
      new(cues: cues, annotations: annotations).call
    end

    def initialize(cues:, annotations:)
      @cues = Array(cues).map { |cue| cue.with_indifferent_access }
      @annotations = (annotations || {}).each_with_object({}) do |(key, value), memo|
        memo[key.to_s] = value.with_indifferent_access
      end
    end

    def call
      return { cues: [], annotations: {} } if @cues.empty?

      groups = []
      current = [@cues.first]

      @cues.drop(1).each do |cue|
        if should_collapse?(current.last, cue)
          current << cue
        else
          groups << current
          current = [cue]
        end
      end
      groups << current

      cues_out = []
      annotations_out = {}

      groups.each_with_index do |atoms, index|
        id = "cue-#{index + 1}"
        first = atoms.first
        last = atoms.last
        annotation = merge_annotations(atoms)
        texts = atoms.map { |atom| atom[:text].to_s.strip }.reject(&:blank?)

        cues_out << {
          "id" => id,
          "index" => index + 1,
          "start" => first[:start],
          "end" => last[:end],
          "start_ms" => first[:start_ms],
          "end_ms" => last[:end_ms],
          "speaker_label" => first[:speaker_label].to_s,
          "text" => texts.join(" ").squeeze(" ").strip,
          "kind" => first[:kind].to_s,
          "source_cue_ids" => atoms.flat_map { |atom| Array(atom[:source_cue_ids]).presence || [atom[:id].to_s] },
          "source_block_count" => atoms.sum { |atom| atom[:source_block_count].to_i.positive? ? atom[:source_block_count].to_i : 1 },
          "merged" => atoms.size > 1 || ActiveModel::Type::Boolean.new.cast(first[:merged])
        }
        annotations_out[id] = annotation.merge("cue_id" => id)
      end

      { cues: cues_out, annotations: annotations_out }
    end

    private

    def should_collapse?(previous, nxt)
      return false unless same_speaker?(previous, nxt)
      return false if worthy?(previous) || worthy?(nxt)

      true
    end

    def same_speaker?(a, b)
      a[:speaker_label].to_s.strip == b[:speaker_label].to_s.strip &&
        a[:speaker_label].to_s.strip.present?
    end

    def worthy?(cue)
      annotation = @annotations[cue[:id].to_s] || {}
      if annotation.key?(:ogo_worthy)
        return ActiveModel::Type::Boolean.new.cast(annotation[:ogo_worthy])
      end

      annotation[:cue_status].to_s == "ogo_worthy"
    end

    def merge_annotations(atoms)
      rows = atoms.map { |atom| (@annotations[atom[:id].to_s] || {}).stringify_keys }
      primary = rows.first || {}
      reasons = rows.map { |row| row["first_pass_reason"].to_s.strip }.reject(&:blank?).uniq
      worthy = atoms.any? { |atom| worthy?(atom) }

      primary.merge(
        "ogo_worthy" => worthy,
        "cue_status" => worthy ? "ogo_worthy" : "ignore",
        "first_pass_reason" => reasons.join("; ").truncate(500)
      )
    end
  end
end
