# frozen_string_literal: true

module SeatSuggestions
  # User-facing lifecycle for Seat Suggestion chats (not raw OgConsultation status).
  class ConversationStatus
    IN_PROGRESS = "In progress"
    DRAFT_BEING_REVIEWED = "Draft being reviewed"
    SUGGESTION_CREATED = "Suggestion created"

    BADGE_CLASS = {
      IN_PROGRESS => "text-bg-secondary",
      DRAFT_BEING_REVIEWED => "text-bg-warning",
      SUGGESTION_CREATED => "text-bg-success"
    }.freeze

    def self.for(consultation)
      new(consultation).label
    end

    def self.badge_class_for(consultation)
      BADGE_CLASS.fetch(self.for(consultation), "text-bg-light")
    end

    def initialize(consultation)
      @consultation = consultation
      @result = consultation.try(:result)
    end

    def label
      return SUGGESTION_CREATED if suggestion_created?
      return DRAFT_BEING_REVIEWED if draft_being_reviewed?

      IN_PROGRESS
    end

    def badge_class
      BADGE_CLASS.fetch(label, "text-bg-light")
    end

    private

    def suggestion_created?
      return false unless @result.is_a?(AskOgResult)

      @result.confirms_count.to_i.positive?
    end

    def draft_being_reviewed?
      return false unless @result.is_a?(AskOgResult)
      return false if suggestion_created?

      proposed_action_list.any? do |action|
        action.is_a?(Hash) && action["tool"].to_s == "create_seat_suggestion_bundle"
      end
    end

    def proposed_action_list
      latest = @result.latest_assistant_message
      from_message = latest ? Array(latest.proposed_actions) : []
      return from_message if from_message.any?

      Array(@result.proposed_actions)
    end
  end
end

