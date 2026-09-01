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
    return Result.err("Suggestion round is closed") unless @suggestion.open?

    record = @suggestion.milestones.find_or_initialize_by(
      milestoneable_type: @milestoneable.class.name,
      milestoneable_id: @milestoneable.id
    )
    record.suggested_milestone_level = @suggested_milestone_level
    record.last_modified_by = @modified_by
    record.decision = nil
    record.processed_by = nil
    record.processed_at = nil

    if record.save
      notify_if_assignment_ability!(record)
      Result.ok(record)
    else
      Result.err(record.errors.full_messages)
    end
  end

  private

  def notify_if_assignment_ability!(record)
    return unless @milestoneable.is_a?(AssignmentAbility)
    return unless record.saved_change_to_suggested_milestone_level? || record.id_previously_changed?

    notify_result = PositionSuggestions::NotifyMilestoneSuggestionService.call(
      suggestion: @suggestion,
      assignment_ability: @milestoneable,
      suggested_milestone_level: record.suggested_milestone_level,
      modified_by: @modified_by
    )

    return if notify_result.ok?

    Rails.logger.error(
      "Failed to post milestone suggestion comment for " \
      "position_suggestion=#{@suggestion.id} assignment_ability=#{@milestoneable.id}: " \
      "#{Array(notify_result.error).join(', ')}"
    )
  end
end
