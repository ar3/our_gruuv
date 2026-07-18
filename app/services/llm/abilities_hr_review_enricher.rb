# frozen_string_literal: true

module Llm
  # Fills description/milestone "proposed" fields from normalized text (LLM optional).
  class AbilitiesHrReviewEnricher
    def self.enrich_row(row)
      enrich_group(row)
    end

    def self.enrich_group(group, organization:)
      new(group, organization: organization).enrich_row
    end

    def initialize(row, organization: nil)
      @row = row.deep_stringify_keys
      @organization = organization
    end

    def enrich_row
      out = @row.dup
      desc = (@row['description'] || {}).stringify_keys
      out['description'] = desc.merge('proposed' => propose_text(desc['normalized'].presence || desc['raw']))

      milestones = (@row['milestones'] || {}).stringify_keys
      out['milestones'] = {}
      milestones.each_key do |k|
        h = milestones[k].is_a?(Hash) ? milestones[k].stringify_keys : {}
        base = h['normalized'].presence || h['raw'].presence || ''
        out['milestones'][k] = h.merge('proposed' => propose_text(base))
      end

      if @organization.present?
        out = Llm::AbilitiesHrReviewMatcher.apply_to_group(out, organization: @organization)
      end

      out['enrichment_status'] = 'complete'
      out
    end

    private

    def propose_text(text)
      return '' if text.blank?
      return text unless bedrock_configured?

      model_id = ENV.fetch('ABILITIES_HR_REVIEW_BEDROCK_MODEL_ID') { Llm::TranscriptMomentsExtractor.default_model_id }
      llm = Llm::Client.call(
        purpose: 'abilities_hr_enrich',
        model_id: model_id,
        system_instructions: <<~TXT.squish,
          You fix Markdown for HR-written ability descriptions: ensure list items use "* " after asterisks,
          add blank lines around horizontal rules (---), preserve meaning, do not invent facts.
          Return ONLY the cleaned Markdown text, no JSON, no preamble.
        TXT
        user_prompt: "Clean this Markdown:\n\n#{text}",
        organization_id: @organization&.id
      )
      llm.content.to_s.strip.presence || text
    rescue StandardError => e
      Rails.logger.warn("AbilitiesHrReviewEnricher: #{e.class}: #{e.message}")
      text
    end

    def bedrock_configured?
      cfg = RubyLLM.config
      cfg.bedrock_api_key.present? && cfg.bedrock_secret_key.present? && cfg.bedrock_region.present?
    end
  end
end
