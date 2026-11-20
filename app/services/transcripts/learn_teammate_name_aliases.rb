# frozen_string_literal: true

module Transcripts
  # When Step 2 maps a transcript label to a teammate, remember that label as an
  # alias so future first-pass / resolver runs get smarter about who is who.
  class LearnTeammateNameAliases
    def self.call(consult:, created_by: nil)
      new(consult: consult, created_by: created_by).call
    end

    def initialize(consult:, created_by:)
      @consult = consult
      @created_by = created_by
      @learned = 0
    end

    def call
      labels = @consult.speaker_map_labels
      annotations = @consult.cue_annotation_rows

      labels.each_value do |entry|
        entry = entry.with_indifferent_access
        learn(entry[:raw_label].presence || entry[:normalized_label], entry[:company_teammate_id])
      end

      annotations.each_value do |annotation|
        annotation = annotation.with_indifferent_access
        learn(annotation[:observer_label], annotation[:observer_company_teammate_id])

        observee_ids = PossibleObservationConsults::ObserveeSelection.normalize_ids(
          annotation[:observee_company_teammate_ids]
        )
        if observee_ids.empty? && annotation[:observee_company_teammate_id].present?
          observee_ids = [annotation[:observee_company_teammate_id].to_i]
        end
        labels_for_observees = Array(annotation[:observee_labels])
        if observee_ids.one? && labels_for_observees.one?
          learn(labels_for_observees.first, observee_ids.first)
        elsif observee_ids.size == labels_for_observees.size
          observee_ids.zip(labels_for_observees).each do |teammate_id, label|
            learn(label, teammate_id)
          end
        end
      end

      { learned: @learned }
    end

    private

    def learn(raw_label, teammate_id)
      return unless TeammateNameAlias.learnable?(raw_label)

      id = teammate_id.to_i
      return unless id.positive?

      teammate = CompanyTeammate.find_by(id: id)
      return unless teammate

      alias_row = teammate.name_aliases.find_or_initialize_by(
        normalized_name: TeammateNameAlias.normalize(raw_label)
      )
      return if alias_row.persisted?

      alias_row.name = raw_label.to_s.strip
      alias_row.source = "transcript_learn"
      alias_row.created_by_company_teammate = @created_by
      return unless alias_row.valid?

      alias_row.save!
      @learned += 1
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      nil
    end
  end
end
