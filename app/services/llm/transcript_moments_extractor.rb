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

    def self.call(chunk_text:, organization_id: nil, parent: nil, triggered_by_teammate_id: nil)
      new(
        chunk_text: chunk_text,
        organization_id: organization_id,
        parent: parent,
        triggered_by_teammate_id: triggered_by_teammate_id
      ).call
    end

    def initialize(chunk_text:, organization_id: nil, parent: nil, triggered_by_teammate_id: nil)
      @chunk_text = chunk_text.to_s
      @organization_id = organization_id
      @parent = parent
      @triggered_by_teammate_id = triggered_by_teammate_id
    end

    # Returns { "items" => [ { "kind", "summary", "short_quote", "full_quote", "quote", "speaker_label", "recipient_label" }, ... ] }.
    def call
      return stub_response unless bedrock_configured?

      # Bedrock foundation model and inference-profile IDs (e.g. us.anthropic...) are often
      # absent from RubyLLM's bundled registry — skip registry lookup and pass the id through.
      model_id = ENV.fetch('TRANSCRIPT_BEDROCK_MODEL_ID') { self.class.default_model_id }
      llm = Llm::Client.call(
        purpose: 'transcript_chunk',
        model_id: model_id,
        system_instructions: system_instructions,
        user_prompt: user_prompt,
        organization_id: @organization_id,
        parent: @parent,
        triggered_by_teammate_id: @triggered_by_teammate_id
      )
      parse_items(llm.content.to_s)
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
        {"items":[{"kind":"kudos"|"feedback","summary":"This is a story about when <name of recipient> caused <outcome> by <action they took>. And this made me feel <impact it had on the speaker>.",
        "short_quote":"short but accurate quote",
        "full_quote":"complete verbatim quote from transcript",
        "speaker_label":"name as in transcript","recipient_label":"primary addressee name as in transcript"}]}.
        Rules:
        - full_quote must be verbatim from transcript text.
        - short_quote must be concise but still an exact quote from transcript.
        - summary must follow the exact sentence pattern above and stay faithful to transcript facts.
        - Never invent names or details not present in transcript.
        If none, return {"items":[]}.
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

        full_quote = h['full_quote'].to_s.strip
        short_quote = h['short_quote'].to_s.strip
        summary = h['summary'].to_s.strip
        legacy_quote = h['quote'].to_s.strip

        full_quote = legacy_quote if full_quote.blank?
        short_quote = legacy_quote if short_quote.blank?
        summary = default_summary(
          recipient_label: h['recipient_label'].to_s,
          quote: short_quote.presence || full_quote.presence || legacy_quote
        ) if summary.blank?

        {
          'kind' => (h['kind'].to_s == 'feedback' ? 'feedback' : 'kudos'),
          'summary' => summary.truncate(2500),
          'short_quote' => short_quote.truncate(2500),
          'full_quote' => full_quote.truncate(10_000),
          'quote' => compose_display_quote(
            summary: summary,
            short_quote: short_quote,
            full_quote: full_quote
          ).truncate(20_000),
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

    def compose_display_quote(summary:, short_quote:, full_quote:)
      [
        "Summary: #{summary.presence || '(none)'}",
        '',
        '',
        '====================',
        '',
        '',
        "Short quote: #{short_quote.presence || '(none)'}",
        '',
        '',
        '====================',
        '',
        '',
        "Full quote: #{full_quote.presence || '(none)'}"
      ].join("\n")
    end

    def default_summary(recipient_label:, quote:)
      name = recipient_label.presence || 'the recipient'
      quote_text = quote.presence || 'what happened'
      "This is a story about when #{name} caused an outcome by actions they took. And this made me feel impacted by \"#{quote_text}\"."
    end
  end
end
