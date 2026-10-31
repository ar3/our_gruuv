# frozen_string_literal: true

module PossibleObservationConsults
  # People OG will search for = observers + observees on OGO-worthy cues that have a teammate.
  class DeriveConfirmedTeammateIds
    def self.call(consult:)
      new(consult: consult).call
    end

    def initialize(consult:)
      @consult = consult
    end

    def call
      labels = @consult.speaker_map_labels
      annotations = @consult.cue_annotation_rows
      cues = @consult.moment_cues
      ids = []

      cues.each do |cue|
        cue = cue.with_indifferent_access
        annotation = (annotations[cue[:id].to_s] || {}).with_indifferent_access
        next unless annotation[:cue_status].to_s == "ogo_worthy"

        observer = (labels[cue[:speaker_label].to_s] || {}).with_indifferent_access
        if observer[:company_teammate_id].present?
          ids << observer[:company_teammate_id].to_i
        end
        if annotation[:observee_company_teammate_id].present?
          ids << annotation[:observee_company_teammate_id].to_i
        end
      end

      ids.reject(&:zero?).uniq
    end
  end
end
