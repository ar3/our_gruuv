# frozen_string_literal: true

module Llm
  # Calls Bedrock via RubyLLM to extract kudos / constructive feedback moments from one transcript chunk.
  class TranscriptMomentsExtractor
    # Default: Anthropic Claude Haiku 4.5 via Bedrock regional inference profile (e.g. `us.anthropic...`).
    # Bare foundation IDs like `anthropic.claude-haiku-4-5-...` often fail Converse with on-demand in newer regions.
    # Override with TRANSCRIPT_BEDROCK_MODEL_ID if your account lists a different profile ARN/id.
    #   Llm::BedrockModelCatalog.print_suggestions
    #   Llm::BedrockModelCatalog.suggested_model_id
    HAIKU_45_FOUNDATION_SUFFIX = 'anthropic.claude-haiku-4-5-20251001-v1:0'

    def self.default_model_id
      region = RubyLLM.config.bedrock_region.presence || ENV['AWS_REGION'].presence || 'us-east-1'
      prefix =
        if region.to_s.match?(/\Aus-gov-/i)
          'us-gov'
        else
          region.to_s.split('-').first.presence || 'us'
        end
      "#{prefix}.#{HAIKU_45_FOUNDATION_SUFFIX}"
    end

    def self.call(chunk_text:)
      new(chunk_text: chunk_text).call
    end

    def initialize(chunk_text:)
      @chunk_text = chunk_text.to_s
    end

    # Returns { "items" => [ { "kind", "quote", "speaker_label", "recipient_label" }, ... ] } or raises / returns empty on stub.
    def call
      return stub_response unless bedrock_configured?

      # Bedrock foundation model and inference-profile IDs (e.g. us.anthropic...) are often
      # absent from RubyLLM's bundled registry — skip registry lookup and pass the id through.
      model_id = ENV.fetch('TRANSCRIPT_BEDROCK_MODEL_ID') { self.class.default_model_id }
      chat = RubyLLM.chat(model: model_id, provider: :bedrock, assume_model_exists: true)
      chat.with_instructions(system_instructions)
      response = chat.ask(user_prompt)
      parse_items(response.content.to_s)
    rescue StandardError => e
      Rails.logger.warn(
        "TranscriptMomentsExtractor failed: #{e.class}: #{e.message} " \
        "(transcript_chunk_chars=#{@chunk_text.bytesize})"
      )
      { 'items' => [], 'error' => e.message }
    end

    private

    def bedrock_configured?
      cfg = RubyLLM.config
      cfg.bedrock_api_key.present? && cfg.bedrock_secret_key.present? && cfg.bedrock_region.present?
    end

    def stub_response
      {
        'items' => [],
        'error' => 'AWS Bedrock is not configured (missing access key, secret, or region). Set credentials to enable extraction.'
      }
    end

    def system_instructions
      <<~TXT.squish
        You extract moments from meeting transcripts where one speaker gives another person kudos (praise)
        or constructive feedback. Return ONLY valid JSON with shape:
        {"items":[{"kind":"kudos"|"feedback","quote":"exact excerpt from transcript","speaker_label":"name as in transcript",
        "recipient_label":"primary addressee name as in transcript"}]}.
        Use short accurate quotes. If none, return {"items":[]}.
      TXT
    end

    def user_prompt
      <<~TXT
        Transcript excerpt:
        ---
        #{@chunk_text.truncate(120_000)}
        ---
      TXT
    end

    def parse_items(raw)
      json = extract_json_object(raw)
      data = JSON.parse(json)
      items = Array(data['items']).filter_map do |h|
        next unless h.is_a?(Hash)

        {
          'kind' => (h['kind'].to_s == 'feedback' ? 'feedback' : 'kudos'),
          'quote' => h['quote'].to_s.strip.truncate(5000),
          'speaker_label' => h['speaker_label'].to_s.strip,
          'recipient_label' => h['recipient_label'].to_s.strip
        }
      end
      { 'items' => items }
    rescue JSON::ParserError => e
      { 'items' => [], 'error' => "Invalid JSON from model: #{e.message}" }
    end

    def extract_json_object(raw)
      text = raw.to_s.strip
      if (m = text.match(/\{.*\}/m))
        m[0]
      else
        '{}'
      end
    end
  end
end
