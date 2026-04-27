# frozen_string_literal: true

module Llm
  # Lists Bedrock foundation models via RubyLLM (same credentials as transcript extraction).
  # Use from rails console to pick TRANSCRIPT_BEDROCK_MODEL_ID:
  #   Llm::BedrockModelCatalog.print_suggestions
  #   Llm::BedrockModelCatalog.suggested_model_id
  module BedrockModelCatalog
    module_function

    def print_suggestions(io: $stdout)
      cfg = RubyLLM.config
      unless cfg.bedrock_api_key.present? && cfg.bedrock_secret_key.present? && cfg.bedrock_region.present?
        io.puts "Bedrock is not configured (missing access key, secret, or region)."
        return
      end

      rows = ranked_text_claude_models
      if rows.empty?
        io.puts "No Claude text models returned from Bedrock for region #{cfg.bedrock_region}."
        return
      end

      io.puts "Region: #{cfg.bedrock_region}"
      io.puts "Heuristic pick (verify in AWS console / model access):"
      io.puts "  TRANSCRIPT_BEDROCK_MODEL_ID=#{suggested_model_id.inspect}"
      io.puts
      io.printf "%-75s  %-18s  %s\n", "MODEL_ID", "INFERENCE_TYPES", "NAME"
      rows.each do |m|
        types = Array(m.metadata[:inference_types]).join(',')
        io.printf "%-75s  %-18s  %s\n", m.id, types.truncate(18), m.name.to_s.truncate(55)
      end
    rescue StandardError => e
      io.puts "#{e.class}: #{e.message}"
    end

    # Best-effort default for transcript extraction: prefer small/fast Haiku 4.x on-demand when listed.
    def suggested_model_id
      ranked_text_claude_models.first&.id
    end

    def ranked_text_claude_models
      provider = RubyLLM::Providers::Bedrock.new(RubyLLM.config)
      provider.list_models.select do |m|
        m.id.to_s.match?(/claude/i) && m.modalities.input.include?('text')
      end.sort_by { |m| sort_keys(m) }
    end

    # Sort keys: lower tuple sorts first (prefer Haiku 4.5, then Haiku 4.x; prefer regional inference profile ids).
    def sort_keys(model)
      id = model.id.to_s.downcase
      types = Array(model.metadata[:inference_types])
      # Converse often requires `us.` / `eu.` / `ap.` profile ids; bare `anthropic.*` may reject on-demand.
      regional_profile = id.match?(/\A(us|eu|ap|ca)\.anthropic\./) ? 0 : 1
      on_demand = types.include?('ON_DEMAND') ? 0 : 1

      primary =
        if id.match?(/haiku-4-5/)
          0
        elsif id.match?(/haiku-4-/)
          1
        elsif id.include?('haiku')
          2
        elsif id.match?(/sonnet-4/)
          3
        elsif id.include?('sonnet')
          4
        else
          5
        end

      profile_only = types.include?('INFERENCE_PROFILE') && !types.include?('ON_DEMAND') ? 0 : 1

      [primary, regional_profile, profile_only, on_demand, id]
    end
  end
end
