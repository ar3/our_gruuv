# frozen_string_literal: true

class PositionSuggestions::JoinService
  def self.call(suggestion:, company_teammate:)
    new(suggestion: suggestion, company_teammate: company_teammate).call
  end

  def initialize(suggestion:, company_teammate:)
    @suggestion = suggestion
    @company_teammate = company_teammate
  end

  def call
    return Result.err("Suggestion round is closed") unless @suggestion.open?

    participant = @suggestion.participants.find_or_initialize_by(company_teammate: @company_teammate)
    participant.participation_status = "active" if participant.new_record? || participant.withdrawn?
    if participant.save
      Result.ok(participant)
    else
      Result.err(participant.errors.full_messages)
    end
  end
end
