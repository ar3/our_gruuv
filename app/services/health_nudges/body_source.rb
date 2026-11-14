# frozen_string_literal: true

module HealthNudges
  # Classifies what the sender used as the basis for the final nudge body.
  module BodySource
    SUGGESTED = "suggested"
    OG_CONSULTED = "og_consulted"
    CUSTOM_FROM_SUGGESTED = "custom_from_suggested"
    CUSTOM_FROM_OG_CONSULTED = "custom_from_og_consulted"
    ALL = [SUGGESTED, OG_CONSULTED, CUSTOM_FROM_SUGGESTED, CUSTOM_FROM_OG_CONSULTED].freeze

    module_function

    def resolve(sent:, suggested:, og_consulted:, base: nil)
      sent_text = sent.to_s
      suggested_text = suggested.to_s
      og_text = og_consulted.to_s

      return SUGGESTED if sent_text == suggested_text && suggested_text.present?
      return OG_CONSULTED if og_text.present? && sent_text == og_text

      if base.to_s == OG_CONSULTED || (og_text.present? && base.to_s != SUGGESTED)
        CUSTOM_FROM_OG_CONSULTED
      else
        CUSTOM_FROM_SUGGESTED
      end
    end
  end
end
