# frozen_string_literal: true

module Llm
  # Cheap Bedrock pass: infer whether a draft goal title should be an OG3 Progressive Outcome
  # and extract baseline / Commit / Stretch / Transform when confidence is high.
  class ProgressiveOutcomeTitleSuggester
    # Prompt version: <major>.<YYYYMMDD>.<minor> — see docs/RULES/prompt-versioning.md
    # 1.20261118.0 — initial OG3 title infer + structured fields
    # 1.20261118.1 — baseline optional; bare [Commit|Stretch|Transform] is a strong OG3 signal
    PROMPT_VERSION = "1.20261118.1"
    NOVA_2_LITE_FOUNDATION_SUFFIX = "amazon.nova-2-lite-v1:0"
    HIGH_CONFIDENCE_THRESHOLD = 0.8
    PURPOSE = "progressive_outcome_title_default"

    Suggestion = Struct.new(
      :apply?, :confidence, :baseline, :commit, :stretch, :transform, :unit, :current_aim, :rationale,
      keyword_init: true
    )

    def self.model_id
      ENV.fetch("PROGRESSIVE_OUTCOME_BEDROCK_MODEL_ID") { default_model_id }
    end

    def self.default_model_id
      "#{SlackMomentsExtractor.region_prefix}.#{NOVA_2_LITE_FOUNDATION_SUFFIX}"
    end

    def self.prompt_version
      PROMPT_VERSION
    end

    def self.call(**kwargs) = new(**kwargs).call

    def initialize(goal:, model_id: nil, triggered_by_teammate_id: nil)
      @goal = goal
      @model_id = model_id.presence || self.class.model_id
      @triggered_by_teammate_id = triggered_by_teammate_id || @goal&.creator_id
    end

    def call
      return reject("missing goal") if @goal.blank?

      result = Client.call(
        purpose: PURPOSE,
        model_id: @model_id,
        system_instructions: system_instructions,
        user_prompt: user_prompt,
        organization_id: @goal.company_id,
        triggered_by_teammate_id: @triggered_by_teammate_id,
        parent: @goal,
        prompt_version: self.class.prompt_version
      )

      parse_suggestion(result.content.to_s)
    rescue StandardError => e
      Rails.logger.warn("ProgressiveOutcomeTitleSuggester failed goal_id=#{@goal&.id}: #{e.message}")
      reject(e.message)
    end

    private

    def system_instructions
      <<~SYS
        You classify draft goal titles for OurGruuv OG3 Progressive Outcomes.

        An OG3 Progressive Outcome is a measurable outcome ladder:
        - Baseline: where we started (not an aim to "hit")
        - Commit: ≈80%+ confident we can hit
        - Stretch: ≈50/50 push aim
        - Transform: near-impossible until someone does it

        Respond with ONLY a JSON object (no markdown) shaped like:
        {
          "is_progressive_outcome": true,
          "confidence": 0.0,
          "baseline": null,
          "commit": null,
          "stretch": null,
          "transform": null,
          "unit": null,
          "current_aim": "commit",
          "rationale": "short reason"
        }

        Rules:
        - confidence is 0.0–1.0 how sure you are this should be an OG3 Progressive Outcome (not a vague objective, activity, or one-off task).
        - Baseline is optional. Many titles only have Commit/Stretch/Transform... that is still a strong OG3 Progressive Outcome.
        - A bare ladder like [60|70|80]% or [1|2|3] (Commit|Stretch|Transform) is a strong progressive signal even without "from baseline to".
        - Set is_progressive_outcome true when the title has a clear numeric ladder (2–3 aims) or baseline→target progress that fits OG3.
        - Fill only fields you can infer from the title. Prefer null over inventing Stretch/Transform or Baseline.
        - unit examples: "%", "customers", "NPS", "pp", "requests". Use "%" when the title uses percent signs.
        - current_aim must be commit, stretch, or transform (usually commit).
        - If the title is not a strong OG3 fit, set is_progressive_outcome false and confidence low.
      SYS
    end

    def user_prompt
      <<~USER
        Goal title:
        #{@goal.title}

        Current goal_type: #{@goal.goal_type}
      USER
    end

    def parse_suggestion(raw)
      data = JSON.parse(extract_json_object(raw))
      confidence = data["confidence"].to_f
      is_progressive = ActiveModel::Type::Boolean.new.cast(data["is_progressive_outcome"])
      commit = data["commit"]
      stretch = data["stretch"]
      transform = data["transform"]
      has_aim = [commit, stretch, transform].any? { |v| v.present? }

      apply = is_progressive && confidence >= HIGH_CONFIDENCE_THRESHOLD && has_aim

      Suggestion.new(
        apply?: apply,
        confidence: confidence,
        baseline: data["baseline"],
        commit: commit,
        stretch: stretch,
        transform: transform,
        unit: data["unit"],
        current_aim: data["current_aim"].presence || "commit",
        rationale: data["rationale"].to_s
      )
    rescue JSON::ParserError => e
      Rails.logger.warn("ProgressiveOutcomeTitleSuggester JSON parse: #{e.message}")
      reject("invalid json")
    end

    def extract_json_object(raw)
      text = raw.to_s.strip
      if (m = text.match(/\{.*\}/m))
        m[0]
      else
        "{}"
      end
    end

    def reject(reason)
      Suggestion.new(
        apply?: false,
        confidence: 0.0,
        baseline: nil,
        commit: nil,
        stretch: nil,
        transform: nil,
        unit: nil,
        current_aim: nil,
        rationale: reason.to_s
      )
    end
  end
end
