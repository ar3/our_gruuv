# frozen_string_literal: true

# Posts session-scoped Assignment comments when bag milestone suggestions change:
# one root per AssignmentAbility, later changes as replies (reuses MAAP comment Slack path).
class PositionSuggestions::NotifyMilestoneSuggestionService
  MILESTONE_LABELS = {
    1 => "Demonstrated",
    2 => "Advanced",
    3 => "Expert",
    4 => "Coach",
    5 => "Industry-Recognized"
  }.freeze

  def self.call(suggestion:, assignment_ability:, suggested_milestone_level:, modified_by:)
    new(
      suggestion: suggestion,
      assignment_ability: assignment_ability,
      suggested_milestone_level: suggested_milestone_level,
      modified_by: modified_by
    ).call
  end

  def initialize(suggestion:, assignment_ability:, suggested_milestone_level:, modified_by:)
    @suggestion = suggestion
    @assignment_ability = assignment_ability
    @suggested_milestone_level = suggested_milestone_level.to_i
    @modified_by = modified_by
  end

  def call
    assignment = @assignment_ability.assignment
    body = suggestion_body
    root = existing_root_comment(assignment)

    if root
      root.unresolve! if root.resolved?
      Comments::CreateService.call(
        comment: Comment.new(body: body),
        commentable: root,
        organization: @suggestion.organization,
        creator: @modified_by.person,
        position_suggestion: @suggestion
      )
    else
      Comments::CreateService.call(
        comment: Comment.new(body: body),
        commentable: assignment,
        organization: @suggestion.organization,
        creator: @modified_by.person,
        position_suggestion: @suggestion,
        suggestion_thread_subject: @assignment_ability
      )
    end
  end

  private

  def existing_root_comment(assignment)
    Comment
      .for_position_suggestion(@suggestion)
      .for_commentable(assignment)
      .for_suggestion_thread_subject(@assignment_ability)
      .root_comments
      .ordered
      .first
  end

  def suggestion_body
    person_name = @modified_by.person.casual_name
    level_label = MILESTONE_LABELS[@suggested_milestone_level] || "Unknown"
    ability_name = @assignment_ability.ability.name
    assignment_title = @assignment_ability.assignment.title
    position_name = @suggestion.position.display_name

    "#{person_name} suggested Milestone #{@suggested_milestone_level} (#{level_label}) " \
      "for Ability #{ability_name} on Assignment #{assignment_title} " \
      "(Position #{position_name})."
  end
end
