# frozen_string_literal: true

module Assistant
  # Focus modes for the MAAP Suggestion chat (evolved Seat Suggestion).
  # Team focus is deferred; Position is only under Seat.
  module MaapSuggestionFocus
    SEAT = "seat"
    ASSIGNMENT = "assignment"
    ABILITIES = "abilities"
    FOCUSES = [SEAT, ASSIGNMENT, ABILITIES].freeze

    TOOLS_BY_FOCUS = {
      SEAT => %w[create_seat_suggestion_bundle],
      ASSIGNMENT => %w[create_assignment_suggestion_bundle],
      ABILITIES => %w[create_ability_suggestion_bundle]
    }.freeze

    module_function

    def valid?(value)
      FOCUSES.include?(value.to_s)
    end

    def normalize(value)
      focus = value.to_s.strip.downcase
      return focus if valid?(focus)

      nil
    end

    def from_tool_context(tool_context)
      normalize(tool_context.is_a?(Hash) ? tool_context["suggestion_focus"] : nil)
    end

    def tools_for(focus)
      TOOLS_BY_FOCUS.fetch(normalize(focus) || SEAT, TOOLS_BY_FOCUS[SEAT])
    end

    def label_for(focus)
      case normalize(focus)
      when SEAT then "Seat"
      when ASSIGNMENT then "Assignment"
      when ABILITIES then "Abilities"
      else "MAAP"
      end
    end
  end
end
