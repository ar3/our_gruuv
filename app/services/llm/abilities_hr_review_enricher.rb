# frozen_string_literal: true

module Llm
  # Fills description/milestone "proposed" fields from normalized text (LLM optional).
  class AbilitiesHrReviewEnricher
    def self.enrich_row(row)
      new(row).enrich_row
    end

    def initialize(row)
      @row = row.deep_stringify_keys
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

      out['enrichment_status'] = 'complete'
      out
    end

    private

    def propose_text(text)
      return '' if text.blank?
      return text unless bedrock_configured?

      model_id = ENV.fetch('ABILITIES_HR_REVIEW_BEDROCK_MODEL_ID') { Llm::TranscriptMomentsExtractor.default_model_id }
      chat = RubyLLM.chat(model: model_id, provider: :bedrock, assume_model_exists: true)
      chat.with_instructions(<<~TXT.squish)
        You fix Markdown for HR-written ability descriptions: ensure list items use "* " after asterisks,
        add blank lines around horizontal rules (---), preserve meaning, do not invent facts.
        Return ONLY the cleaned Markdown text, no JSON, no preamble.
      TXT
      response = chat.ask("Clean this Markdown:\n\n#{text}")
      response.content.to_s.strip.presence || text
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
