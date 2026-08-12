# frozen_string_literal: true

class PositionSuggestions::UpsertAssignmentDraftService
  def self.call(suggestion:, source_assignment:, attributes:, outcomes:, modified_by:)
    new(
      suggestion: suggestion,
      source_assignment: source_assignment,
      attributes: attributes,
      outcomes: outcomes,
      modified_by: modified_by
    ).call
  end

  def initialize(suggestion:, source_assignment:, attributes:, outcomes:, modified_by:)
    @suggestion = suggestion
    @source_assignment = source_assignment
    @attributes = attributes
    @outcomes = Array(outcomes)
    @modified_by = modified_by
  end

  def call
    return Result.err("Suggestion round is closed") unless @suggestion.open?

    unless @suggestion.position.assignments.exists?(id: @source_assignment.id)
      return Result.err("Assignment is not on this position")
    end

    draft = @suggestion.assignment_drafts.find_or_initialize_by(source_assignment: @source_assignment)
    previous_snapshot = draft.persisted? ? draft.field_snapshot : nil
    first_save = draft.new_record?
    proposed_snapshot = proposed_field_snapshot

    if first_save && proposed_snapshot == live_field_snapshot
      return Result.err("No changes from current MAAP")
    end

    if !first_save && proposed_snapshot == previous_snapshot
      return Result.ok(draft)
    end

    ApplicationRecord.transaction do
      draft.assign_attributes(
        title: @attributes[:title].to_s.strip,
        tagline: blank_to_nil(@attributes[:tagline]),
        required_activities: blank_to_nil(@attributes[:required_activities]),
        handbook: blank_to_nil(@attributes[:handbook]),
        last_modified_by: @modified_by
      )
      draft.save!

      draft.outcomes.destroy_all
      @outcomes.each_with_index do |outcome_attrs, index|
        description = outcome_attrs[:description].to_s.strip
        next if description.blank?

        draft.outcomes.create!(
          description: description,
          outcome_type: outcome_attrs[:outcome_type].presence || "quantitative",
          progress_report_url: blank_to_nil(outcome_attrs[:progress_report_url]),
          management_relationship_filter: blank_to_nil(outcome_attrs[:management_relationship_filter]),
          team_relationship_filter: blank_to_nil(outcome_attrs[:team_relationship_filter]),
          consumer_assignment_filter: blank_to_nil(outcome_attrs[:consumer_assignment_filter]),
          position: index
        )
      end

      draft.reload
      notify_result = PositionSuggestions::NotifyAssignmentDraftSuggestionService.call(
        suggestion: @suggestion,
        draft: draft,
        modified_by: @modified_by,
        first_save: first_save,
        previous_snapshot: previous_snapshot
      )

      unless notify_result.ok?
        Rails.logger.error(
          "Failed to post assignment draft suggestion comment for " \
          "position_suggestion=#{@suggestion.id} assignment=#{@source_assignment.id}: " \
          "#{Array(notify_result.error).join(', ')}"
        )
      end

      Result.ok(draft)
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.err(e.record.errors.full_messages)
  end

  private

  def blank_to_nil(value)
    str = value.to_s
    str.strip.empty? ? nil : str
  end

  def proposed_field_snapshot
    {
      "title" => @attributes[:title].to_s.strip,
      "tagline" => blank_to_nil(@attributes[:tagline]),
      "required_activities" => blank_to_nil(@attributes[:required_activities]),
      "handbook" => blank_to_nil(@attributes[:handbook]),
      "outcomes" => proposed_outcomes_fingerprint
    }
  end

  def proposed_outcomes_fingerprint
    @outcomes.filter_map do |outcome_attrs|
      description = outcome_attrs[:description].to_s.strip
      next if description.blank?

      [
        description,
        (outcome_attrs[:outcome_type].presence || "quantitative").to_s,
        outcome_attrs[:progress_report_url].to_s,
        outcome_attrs[:management_relationship_filter].to_s,
        outcome_attrs[:team_relationship_filter].to_s,
        outcome_attrs[:consumer_assignment_filter].to_s
      ]
    end
  end

  def live_field_snapshot
    live = @source_assignment
    {
      "title" => live.title.to_s,
      "tagline" => blank_to_nil(live.tagline),
      "required_activities" => blank_to_nil(live.required_activities),
      "handbook" => blank_to_nil(live.handbook),
      "outcomes" => live.assignment_outcomes.ordered.map do |outcome|
        [
          outcome.description.to_s,
          outcome.outcome_type.to_s,
          outcome.progress_report_url.to_s,
          outcome.management_relationship_filter.to_s,
          outcome.team_relationship_filter.to_s,
          outcome.consumer_assignment_filter.to_s
        ]
      end
    }
  end
end
