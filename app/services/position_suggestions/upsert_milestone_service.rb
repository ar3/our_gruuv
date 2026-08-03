# frozen_string_literal: true

class PositionSuggestions::UpsertMilestoneService
  def self.call(suggestion:, milestoneable:, suggested_milestone_level:, modified_by:)
    new(
      suggestion: suggestion,
      milestoneable: milestoneable,
      suggested_milestone_level: suggested_milestone_level,
      modified_by: modified_by
    ).call
  end

  def initialize(suggestion:, milestoneable:, suggested_milestone_level:, modified_by:)
    @suggestion = suggestion
    @milestoneable = milestoneable
    @suggested_milestone_level = suggested_milestone_level
    @modified_by = modified_by
  end

  def call
    return Result.err("Suggestion session is closed") unless @suggestion.open?

    record = @suggestion.milestones.find_or_initialize_by(
      milestoneable_type: @milestoneable.class.name,
      milestoneable_id: @milestoneable.id
    )
    record.suggested_milestone_level = @suggested_milestone_level
    record.last_modified_by = @modified_by

    if record.save
      Result.ok(record)
    else
      Result.err(record.errors.full_messages)
    end
  end
end
