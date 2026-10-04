# frozen_string_literal: true

module SeatSuggestionsHelper
  def seat_suggestion_conversation_status(consultation)
    SeatSuggestions::ConversationStatus.for(consultation)
  end

  def seat_suggestion_conversation_status_badge_class(consultation)
    SeatSuggestions::ConversationStatus.badge_class_for(consultation)
  end
end
