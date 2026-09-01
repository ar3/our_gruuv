# frozen_string_literal: true

class PositionSuggestions::ProcessMilestoneDecisionService
  def self.call(suggestion:, milestone:, decision:, processed_by:)
    new(
      suggestion: suggestion,
      milestone: milestone,
      decision: decision,
      processed_by: processed_by
    ).call
  end

  def initialize(suggestion:, milestone:, decision:, processed_by:)
    @suggestion = suggestion
    @milestone = milestone
    @decision = decision.to_s
    @processed_by = processed_by
  end

  def call
    return Result.err("Suggestion round is closed") unless @suggestion.open?
    return Result.err("Unknown decision") unless PositionSuggestionMilestone::DECISIONS.include?(@decision)
    return Result.err("Milestone suggestion was already processed") if @milestone.processed?
    return Result.err("Only AssignmentAbility milestones can be applied in this release") unless assignment_ability_milestone?

    validation_error = validate_assignment_on_position!
    return Result.err(validation_error) if validation_error

    ApplicationRecord.transaction do
      apply_to_maap! if @decision == "accepted"

      @milestone.update!(
        decision: @decision,
        processed_by: @processed_by,
        processed_at: Time.current
      )

      resolve_thread!
      post_decision_comment!
    end

    Result.ok(@milestone)
  rescue ActiveRecord::RecordInvalid => e
    Result.err(e.record.errors.full_messages)
  end

  private

  def assignment_ability_milestone?
    @milestone.milestoneable.is_a?(AssignmentAbility)
  end

  def assignment_ability
    @milestone.milestoneable
  end

  def validate_assignment_on_position!
    return "Assignment ability is not on this position" unless assignment_ability_milestone?

    assignment_id = assignment_ability.assignment_id
    return nil if @suggestion.position.assignments.exists?(id: assignment_id)

    "Assignment is not on this position"
  end

  def apply_to_maap!
    assignment_ability.update!(milestone_level: @milestone.suggested_milestone_level)
  end

  def resolve_thread!
    root = thread_root
    return unless root
    return if root.resolved?

    Comments::ResolveService.call(comment: root)
  end

  def post_decision_comment!
    root = thread_root
    return unless root

    body = decision_comment_body
    Comments::CreateService.call(
      comment: Comment.new(body: body),
      commentable: root,
      organization: @suggestion.organization,
      creator: @processed_by.person,
      position_suggestion: @suggestion
    )
  end

  def thread_root
    return nil unless assignment_ability_milestone?

    assignment = assignment_ability.assignment
    Comment
      .for_position_suggestion(@suggestion)
      .for_commentable(assignment)
      .for_suggestion_thread_subject(assignment_ability)
      .root_comments
      .ordered
      .first
  end

  def decision_comment_body
    person_name = @processed_by.person.casual_name
    ability_name = assignment_ability.ability.name
    assignment_title = assignment_ability.assignment.title
    level = @milestone.suggested_milestone_level

    if @decision == "accepted"
      "#{person_name} accepted this suggestion and applied Milestone #{level} " \
        "for #{ability_name} on Assignment #{assignment_title} to live MAAP."
    else
      "#{person_name} rejected this milestone suggestion for #{ability_name} " \
        "on Assignment #{assignment_title} (Milestone #{level} was not applied to MAAP)."
    end
  end
end
