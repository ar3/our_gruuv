# frozen_string_literal: true

module PossibleObservationConsults
  # Step 3 candidates are exactly the OGO-worthy Step 2 cues — quote and identities frozen.
  class SeedExtractionItemsFromWorthyCues
    def self.call(consult:)
      new(consult: consult).call
    end

    def initialize(consult:)
      @consult = consult
    end

    def call
      annotations = @consult.cue_annotation_rows
      labels = @consult.speaker_map_labels

      @consult.moment_cues.filter_map do |cue|
        cue = cue.with_indifferent_access
        annotation = (annotations[cue[:id].to_s] || {}).with_indifferent_access
        next unless worthy?(annotation)

        build_item(cue, annotation, labels)
      end
    end

    private

    def worthy?(annotation)
      if annotation.key?(:ogo_worthy)
        return ActiveModel::Type::Boolean.new.cast(annotation[:ogo_worthy])
      end

      annotation[:cue_status].to_s == "ogo_worthy"
    end

    def build_item(cue, annotation, labels)
      speaker = cue[:speaker_label].to_s
      speaker_map = (labels[speaker] || {}).with_indifferent_access
      observer_id = annotation[:observer_company_teammate_id].presence || speaker_map[:company_teammate_id]
      observee_id = annotation[:observee_company_teammate_id]
      quote = cue[:text].to_s

      {
        "id" => cue[:id].to_s,
        "cue_id" => cue[:id].to_s,
        "kind" => "kudos",
        "confidence" => nil,
        "quote" => quote,
        "summary" => "",
        "short_quote" => quote,
        "full_quote" => quote,
        "speaker_label" => speaker,
        "recipient_label" => Array(annotation[:observee_labels]).join(", "),
        "responder_company_teammate_id" => observer_id.presence&.to_i,
        "subject_company_teammate_id" => observee_id.presence&.to_i,
        "observer_unknown" => observer_id.blank? || annotation[:observer_certainty].to_s == "uncertain",
        "observee_unknown" => observee_id.blank? || annotation[:observee_certainty].to_s == "uncertain",
        "observer_alternates" => Array(speaker_map[:alternates]),
        "observee_alternates" => [],
        "suggested_rateable_type" => nil,
        "suggested_rateable_id" => nil,
        "suggested_rateable_name" => nil,
        "suggested_rating" => nil,
        "suggested_rateables" => [],
        "association_reason" => "",
        "rating_reason" => "",
        "suggested_goal_id" => nil,
        "include" => false,
        "first_pass_reason" => annotation[:first_pass_reason].to_s
      }
    end
  end
end
