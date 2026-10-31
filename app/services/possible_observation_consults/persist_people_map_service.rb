# frozen_string_literal: true

module PossibleObservationConsults
  # Saves speaker_map + cue annotations from the cue people-map form.
  class PersistPeopleMapService
    CUE_STATUSES = %w[ogo_worthy ignore].freeze
    CERTAINTIES = %w[certain uncertain].freeze

    def self.call(consult:, speaker_map_params:, cue_annotations_params:)
      new(
        consult: consult,
        speaker_map_params: speaker_map_params,
        cue_annotations_params: cue_annotations_params
      ).call
    end

    def initialize(consult:, speaker_map_params:, cue_annotations_params:)
      @consult = consult
      @speaker_map_params = speaker_map_params || {}
      @cue_annotations_params = cue_annotations_params || {}
    end

    def call
      labels = @consult.speaker_map_labels.deep_dup
      @speaker_map_params.each do |raw_label, attrs|
        attrs = stringify(attrs)
        entry = (labels[raw_label.to_s] || {}).stringify_keys
        teammate_id = attrs["company_teammate_id"].presence&.to_i
        teammate_id = nil if teammate_id&.zero?
        certainty = attrs["certainty"].to_s
        certainty = teammate_id.present? ? "certain" : "uncertain" unless CERTAINTIES.include?(certainty)
        certainty = "uncertain" if teammate_id.blank?
        entry.merge!(
          "raw_label" => raw_label.to_s,
          "certainty" => certainty,
          "company_teammate_id" => teammate_id,
          "manual" => true
        )
        entry.delete("status")
        labels[raw_label.to_s] = entry
      end

      cues = @consult.cue_annotation_rows.deep_dup
      # Checkboxes omit unchecked ids — default all submitted map keys, then force
      # non-submitted existing cues to ignore when the form includes ogo_worthy flags.
      submitted_worthy = {}
      @cue_annotations_params.each do |cue_id, attrs|
        attrs = stringify(attrs)
        entry = (cues[cue_id.to_s] || {}).stringify_keys
        worthy =
          if attrs.key?("ogo_worthy")
            # hidden "0" + checkbox "1" may arrive as an Array
            ActiveModel::Type::Boolean.new.cast(Array(attrs["ogo_worthy"]).last)
          elsif attrs["cue_status"].present?
            attrs["cue_status"].to_s == "ogo_worthy"
          else
            entry["cue_status"].to_s == "ogo_worthy"
          end
        submitted_worthy[cue_id.to_s] = worthy

        teammate_id = attrs["observee_company_teammate_id"].presence&.to_i
        teammate_id = nil if teammate_id&.zero?
        certainty = attrs["observee_certainty"].to_s
        certainty = teammate_id.present? ? "certain" : "uncertain" unless CERTAINTIES.include?(certainty)
        certainty = "uncertain" if teammate_id.blank?
        entry.merge!(
          "ogo_worthy" => worthy,
          "cue_status" => worthy ? "ogo_worthy" : "ignore",
          "observee_certainty" => certainty,
          "observee_company_teammate_id" => teammate_id
        )
        entry.delete("observee_status")
        cues[cue_id.to_s] = entry
      end

      if submitted_worthy.any?
        cues.each_key do |cue_id|
          next if submitted_worthy.key?(cue_id)

          entry = cues[cue_id].stringify_keys
          entry["ogo_worthy"] = false
          entry["cue_status"] = "ignore"
          cues[cue_id] = entry
        end
      end

      existing = @consult.cue_annotations.is_a?(Hash) ? @consult.cue_annotations.with_indifferent_access : {}
      @consult.update!(
        speaker_map: { "version" => 1, "labels" => labels },
        cue_annotations: {
          "version" => 1,
          "cues" => cues,
          "moments" => Array(existing[:moments])
        }
      )
      @consult
    end

    private

    def stringify(attrs)
      if attrs.respond_to?(:permit)
        attrs.permit(
          :certainty, :company_teammate_id,
          :cue_status, :ogo_worthy, :observee_certainty, :observee_company_teammate_id
        ).to_h.stringify_keys
      else
        attrs.to_h.stringify_keys
      end
    end
  end
end
