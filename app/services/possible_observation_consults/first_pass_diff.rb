# frozen_string_literal: true

module PossibleObservationConsults
  # Compare frozen AI Step 2 defaults to the current (possibly human-edited) maps.
  class FirstPassDiff
    def self.call(consult:)
      new(consult: consult).call
    end

    def initialize(consult:)
      @consult = consult
    end

    def call
      snapshot = @consult.first_pass_snapshot_hash
      ai_cues = ((snapshot[:cue_annotations] || {})[:cues] || {})
      human_cues = @consult.cue_annotation_rows
      cue_ids = (ai_cues.keys.map(&:to_s) | human_cues.keys.map(&:to_s))

      worthiness_flips = []
      identity_changes = []

      cue_ids.each do |cue_id|
        ai = (ai_cues[cue_id] || {}).with_indifferent_access
        human = (human_cues[cue_id] || {}).with_indifferent_access
        next if ai.blank? && human.blank?

        ai_worthy = worthy?(ai)
        human_worthy = worthy?(human)
        if ai_worthy != human_worthy
          worthiness_flips << {
            "cue_id" => cue_id,
            "ai_ogo_worthy" => ai_worthy,
            "human_ogo_worthy" => human_worthy
          }
        end

        ai_observer = ai[:observer_company_teammate_id].presence&.to_i
        human_observer = human[:observer_company_teammate_id].presence&.to_i
        ai_observees = ObserveeSelection.normalize_ids(ai[:observee_company_teammate_ids])
        ai_observees = [ai[:observee_company_teammate_id].to_i] if ai_observees.empty? && ai[:observee_company_teammate_id].present?
        human_observees = ObserveeSelection.normalize_ids(human[:observee_company_teammate_ids])
        if human_observees.empty? && human[:observee_company_teammate_id].present?
          human_observees = [human[:observee_company_teammate_id].to_i]
        end

        next if ai_observer == human_observer && ai_observees == human_observees

        identity_changes << {
          "cue_id" => cue_id,
          "ai_observer_company_teammate_id" => ai_observer,
          "human_observer_company_teammate_id" => human_observer,
          "ai_observee_company_teammate_ids" => ai_observees,
          "human_observee_company_teammate_ids" => human_observees
        }
      end

      {
        "worthiness_flip_count" => worthiness_flips.size,
        "identity_change_count" => identity_changes.size,
        "worthiness_flips" => worthiness_flips,
        "identity_changes" => identity_changes
      }
    end

    private

    def worthy?(annotation)
      if annotation.key?(:ogo_worthy)
        return ActiveModel::Type::Boolean.new.cast(annotation[:ogo_worthy])
      end

      annotation[:cue_status].to_s == "ogo_worthy"
    end
  end
end
