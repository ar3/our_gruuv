# frozen_string_literal: true

class PositionSuggestions::FindOrOpenService
  def self.call(position:, organization:, opened_by:)
    new(position: position, organization: organization, opened_by: opened_by).call
  end

  def initialize(position:, organization:, opened_by:)
    @position = position
    @organization = organization
    @opened_by = opened_by
  end

  def call
    existing = PositionSuggestion.open_sessions.find_by(position: @position)
    return Result.ok(existing) if existing

    suggestion = PositionSuggestion.new(
      position: @position,
      organization: @organization,
      opened_by: @opened_by,
      status: "open"
    )

    ApplicationRecord.transaction do
      if suggestion.save
        PositionSuggestionParticipant.create!(
          position_suggestion: suggestion,
          company_teammate: @opened_by,
          participation_status: "active"
        )
        Result.ok(suggestion)
      else
        Result.err(suggestion.errors.full_messages)
      end
    end
  rescue ActiveRecord::RecordNotUnique
    # Race: another first joiner won — return their open session and join.
    existing = PositionSuggestion.open_sessions.find_by!(position: @position)
    ensure_participant!(existing)
    Result.ok(existing)
  end

  private

  def ensure_participant!(suggestion)
    suggestion.participants.find_or_create_by!(company_teammate: @opened_by) do |participant|
      participant.participation_status = "active"
    end
  end
end
