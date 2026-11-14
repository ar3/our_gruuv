# frozen_string_literal: true

module HealthNudges
  module ProtectFlowNudgePrompts
    # major.date.minor — bump date/minor when prompt text changes; ask before major.
    PROMPT_VERSION = "1.20261114.1"

    SYSTEM_INSTRUCTIONS = <<~TEXT.freeze
      You help a manager write a short Slack nudge about Overall Health (Protect Flow).
      Write one plain-text message the manager can send (no markdown links, no Slack mrkdwn).
      For each employee who still needs work, weave in the top 2 concrete things the manager
      should consider doing next. Prefer action over diagnosis. Stay under 2600 characters.
      When choosing those top 2, follow the One Thing priority order in the context
      (lower position number = higher leverage). Prefer earlier One Thing items that
      need attention over later ones, and over generic health-signal advice.
      Do not invent facts not present in the context. Do not include a dashboard URL.
      End with a brief supportive closing.
    TEXT

    def self.user_prompt(manager_name:, context_json:, suggested_body:)
      <<~TEXT
        Manager: #{manager_name}
        Prompt version: #{PROMPT_VERSION}

        Current non-LLM suggested draft (you may improve it; keep similar length):
        ---
        #{suggested_body}
        ---

        Structured Overall Health + One Thing priority order + ~45-day signal context (JSON):
        #{context_json}

        Write the plain-text nudge draft now.
      TEXT
    end
  end
end
