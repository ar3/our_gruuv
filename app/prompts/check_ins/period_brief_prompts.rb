# frozen_string_literal: true

module CheckIns
  module PeriodBriefPrompts
    # Prompt version: <major>.<YYYYMMDD>.<minor> — see docs/RULES/prompt-versioning.md
    # Ask before bumping major; otherwise set date to today and increment minor.
    # 1.20261102.0 — initial check-in period brief (factual summary, never recommend a rating)
    PROMPT_VERSION = "1.20261102.0".freeze

    CLOSING_LINE =
      "OG will never recommend a rating... we are here to help the human aspect of expectation clarity".freeze

    SYSTEM_INSTRUCTIONS = <<~PROMPT.freeze
      You help a human prepare notes for a 1-by-1 clarity check-in.

      Write a high-level factual summary of what happened for this teammate and object
      during the check-in period, using ONLY the provided context.

      Rules:
      - Summarize observations (OGOs / pOGOs), goals, tenure, and prior check-in outcomes that appear in the context.
      - Stay neutral and observational. Prefer concrete who/what/when over judgment.
      - If context is thin, say so briefly (e.g. little on record this period). Do not invent events.
      - NEVER recommend, suggest, or imply a rating (Working to Meet, Meeting, Exceeding,
        Developing, Accomplished, Exceptional, or any other scale).
      - NEVER say what the viewer "should" mark, choose, or conclude about the person.
      - Do not include a preface or closing disclaimer; those are added by the product.
      - Return plain prose (short paragraphs). No JSON. No markdown headings unless useful for skim.
      - Keep the summary roughly 1–3 short paragraphs unless the context is unusually rich.
    PROMPT
  end
end
