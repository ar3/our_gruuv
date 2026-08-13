# frozen_string_literal: true

class PositionSuggestions::UpsertAssignmentLinkService
  def self.call(suggestion:, assignment:, attributes:, modified_by:)
    new(
      suggestion: suggestion,
      assignment: assignment,
      attributes: attributes,
      modified_by: modified_by
    ).call
  end

  def initialize(suggestion:, assignment:, attributes:, modified_by:)
    @suggestion = suggestion
    @assignment = assignment
    @attributes = attributes
    @modified_by = modified_by
  end

  def call
    return Result.err("Suggestion round is closed") unless @suggestion.open?

    unless assignment_in_company?
      return Result.err("Assignment must belong to this organization")
    end

    link = @suggestion.assignment_links.find_or_initialize_by(assignment: @assignment)
    previous_snapshot = link.persisted? ? link.edge_snapshot : nil
    first_save = link.new_record?
    proposed_snapshot = proposed_edge_snapshot

    validation_error = validate_action_against_live!(proposed_snapshot["action"])
    return Result.err(validation_error) if validation_error

    if first_save && proposed_snapshot["action"] == "update" && proposed_snapshot == live_edge_snapshot
      return Result.err("No changes from current MAAP")
    end

    if !first_save && proposed_snapshot == previous_snapshot
      return Result.ok(link)
    end

    link.assign_attributes(
      action: proposed_snapshot["action"],
      assignment_type: proposed_snapshot["assignment_type"],
      min_estimated_energy: proposed_snapshot["min_estimated_energy"],
      max_estimated_energy: proposed_snapshot["max_estimated_energy"],
      last_modified_by: @modified_by
    )

    if link.save
      notify_result = PositionSuggestions::NotifyAssignmentLinkSuggestionService.call(
        suggestion: @suggestion,
        link: link,
        modified_by: @modified_by,
        first_save: first_save,
        previous_snapshot: previous_snapshot
      )

      unless notify_result.ok?
        Rails.logger.error(
          "Failed to post assignment link suggestion comment for " \
          "position_suggestion=#{@suggestion.id} assignment=#{@assignment.id}: " \
          "#{Array(notify_result.error).join(', ')}"
        )
      end

      Result.ok(link)
    else
      Result.err(link.errors.full_messages)
    end
  end

  private

  def assignment_in_company?
    company_id = @suggestion.organization.root_company&.id || @suggestion.organization_id
    @assignment.company_id == company_id
  end

  def on_position?
    @suggestion.position.assignments.exists?(id: @assignment.id)
  end

  def validate_action_against_live!(action)
    case action
    when "add"
      return "Assignment is already on this position" if on_position?
    when "update", "remove"
      return "Assignment is not on this position" unless on_position?
    else
      return "Unknown action"
    end

    nil
  end

  def proposed_edge_snapshot
    {
      "action" => @attributes[:action].to_s,
      "assignment_type" => @attributes[:assignment_type].to_s,
      "min_estimated_energy" => integer_or_nil(@attributes[:min_estimated_energy]),
      "max_estimated_energy" => integer_or_nil(@attributes[:max_estimated_energy])
    }
  end

  def live_edge_snapshot
    pa = @suggestion.position.position_assignments.find_by(assignment_id: @assignment.id)
    return nil unless pa

    {
      "action" => "update",
      "assignment_type" => pa.assignment_type.to_s,
      "min_estimated_energy" => pa.min_estimated_energy,
      "max_estimated_energy" => pa.max_estimated_energy
    }
  end

  def integer_or_nil(value)
    return nil if value.nil?

    str = value.to_s.strip
    return nil if str.empty?

    Integer(str, exception: false)
  end
end
