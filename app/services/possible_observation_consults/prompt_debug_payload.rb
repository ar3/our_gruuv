# frozen_string_literal: true

module PossibleObservationConsults
  # Builds a chat-friendly JSON dump: AI defaults vs labeled candidates.
  class PromptDebugPayload
    COMPARE_KEYS = %w[
      quote summary short_quote full_quote kind confidence
      speaker_label recipient_label
      responder_company_teammate_id subject_company_teammate_id
      suggested_rateable_type suggested_rateable_id suggested_rateable_name
      suggested_rating suggested_goal_id
      include dismissed_at
    ].freeze

    def self.call(consult:, consultation: nil)
      new(consult: consult, consultation: consultation).call
    end

    def initialize(consult:, consultation: nil)
      @consult = consult
      @consultation = consultation || OgConsultation.latest_for(
        subject: consult,
        kind: OgConsultation::KIND_OGO_SEARCH_CONSULT
      )
    end

    def call
      ai_items = @consult.ai_extraction_items
      labeled = @consult.extraction_items
      {
        format_version: 1,
        purpose: "ogo_consult_prompt_debug",
        generated_at: Time.current.iso8601,
        consult: {
          id: @consult.id,
          display_name: @consult.display_name,
          organization_id: @consult.organization_id,
          prompt_debug: @consult.prompt_debug?,
          extraction_status: @consult.extraction_status,
          confirmed_teammate_ids: Array(@consult.confirmed_teammate_ids).map(&:to_i),
          source_provider: source_provider,
          source_text_preview: source_preview
        },
        consultation: consultation_meta,
        counts: {
          ai_items: ai_items.size,
          labeled_items: labeled.size,
          would_include: labeled.count { |item| ActiveModel::Type::Boolean.new.cast(item[:include]) },
          dismissed: labeled.count { |item| item[:dismissed_at].present? },
          still_reviewing: labeled.count do |item|
            item[:dismissed_at].blank? &&
              !ActiveModel::Type::Boolean.new.cast(item[:include]) &&
              item[:observation_id].blank?
          end,
          already_promoted: labeled.count { |item| item[:observation_id].present? }
        },
        ai_items: ai_items.map { |item| item.to_h.stringify_keys },
        labeled_items: labeled.map { |item| item.to_h.stringify_keys },
        diff: build_diff(ai_items, labeled)
      }
    end

    private

    def source_provider
      meta = @consult.source_metadata
      return nil unless meta.is_a?(Hash)

      meta.with_indifferent_access[:provider]
    end

    def source_preview
      text = @consult.plaintext.to_s
      return "" if text.blank?

      text.truncate(2_000)
    end

    def consultation_meta
      return nil unless @consultation

      invocations = @consultation.llm_invocations.order(:id)
      {
        id: @consultation.id,
        kind: @consultation.kind,
        status: @consultation.status,
        prompt_version: @consultation.prompt_version,
        model_id: @consultation.model_id,
        llm_invocation_ids: invocations.pluck(:id),
        llm_purposes: invocations.pluck(:purpose).uniq
      }
    end

    def build_diff(ai_items, labeled)
      ai_by_id = ai_items.index_by { |item| item[:id].to_s }
      labeled_by_id = labeled.index_by { |item| item[:id].to_s }
      ids = (ai_by_id.keys + labeled_by_id.keys).uniq

      ids.map do |id|
        ai = ai_by_id[id]
        final = labeled_by_id[id]
        {
          id: id,
          outcome: outcome_for(ai, final),
          field_changes: field_changes(ai, final)
        }
      end
    end

    def outcome_for(ai, final)
      return "human_added" if ai.nil? && final.present?
      return "missing_from_labels" if ai.present? && final.nil?
      return "promoted" if final[:observation_id].present?
      return "dismissed" if final[:dismissed_at].present?
      return "would_include" if ActiveModel::Type::Boolean.new.cast(final[:include])
      return "still_reviewing" if final[:dismissed_at].blank? &&
                                  !ActiveModel::Type::Boolean.new.cast(final[:include])

      "unchanged_label_state"
    end

    def field_changes(ai, final)
      return {} if ai.nil? || final.nil?

      changes = {}
      COMPARE_KEYS.each do |key|
        before = normalize_value(ai[key])
        after = normalize_value(final[key])
        next if before == after

        changes[key] = { "from" => before, "to" => after }
      end
      changes
    end

    def normalize_value(value)
      case value
      when true, false then value
      when nil then nil
      else value.to_s
      end
    end
  end
end
