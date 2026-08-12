# frozen_string_literal: true

# One system thread per Assignment draft (suggestion_thread_subject = draft).
# First save: fields that differ from live MAAP. Later saves: fields that changed vs previous draft.
class PositionSuggestions::NotifyAssignmentDraftSuggestionService
  FIELD_LABELS = {
    "title" => "Title",
    "tagline" => "Tagline",
    "required_activities" => "Required activities",
    "handbook" => "Handbook",
    "outcomes" => "Outcomes"
  }.freeze

  def self.call(suggestion:, draft:, modified_by:, first_save:, previous_snapshot:)
    new(
      suggestion: suggestion,
      draft: draft,
      modified_by: modified_by,
      first_save: first_save,
      previous_snapshot: previous_snapshot
    ).call
  end

  def initialize(suggestion:, draft:, modified_by:, first_save:, previous_snapshot:)
    @suggestion = suggestion
    @draft = draft
    @modified_by = modified_by
    @first_save = first_save
    @previous_snapshot = previous_snapshot
  end

  def call
    changes = @first_save ? diff_against_live : diff_against_previous
    return Result.ok(:no_changes) if changes.empty?

    body = build_body(changes)
    assignment = @draft.source_assignment
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
        suggestion_thread_subject: @draft
      )
    end
  end

  private

  def existing_root_comment(assignment)
    Comment
      .for_position_suggestion(@suggestion)
      .for_commentable(assignment)
      .for_suggestion_thread_subject(@draft)
      .root_comments
      .ordered
      .first
  end

  def diff_against_live
    live = @draft.source_assignment
    live_snapshot = {
      "title" => live.title.to_s,
      "tagline" => normalize_text(live.tagline),
      "required_activities" => normalize_text(live.required_activities),
      "handbook" => normalize_text(live.handbook),
      "outcomes" => live_outcomes_fingerprint(live)
    }
    draft_snapshot = {
      "title" => @draft.title.to_s,
      "tagline" => normalize_text(@draft.tagline),
      "required_activities" => normalize_text(@draft.required_activities),
      "handbook" => normalize_text(@draft.handbook),
      "outcomes" => @draft.outcomes_fingerprint
    }
    diff_snapshots(live_snapshot, draft_snapshot)
  end

  def diff_against_previous
    return diff_against_live if @previous_snapshot.blank?

    diff_snapshots(@previous_snapshot, @draft.field_snapshot)
  end

  def live_outcomes_fingerprint(assignment)
    assignment.assignment_outcomes.ordered.map do |outcome|
      [
        outcome.description.to_s,
        outcome.outcome_type.to_s,
        outcome.progress_report_url.to_s,
        outcome.management_relationship_filter.to_s,
        outcome.team_relationship_filter.to_s,
        outcome.consumer_assignment_filter.to_s
      ]
    end
  end

  def diff_snapshots(before, after)
    changes = {}
    FIELD_LABELS.each_key do |key|
      next if before[key] == after[key]

      changes[key] = { from: before[key], to: after[key] }
    end
    changes
  end

  def build_body(changes)
    person_name = @modified_by.person.casual_name
    assignment_title = @draft.source_assignment.title
    position_name = @suggestion.position.display_name
    header =
      if @first_save
        "#{person_name} suggested Assignment field changes for #{assignment_title} " \
          "(Position #{position_name}):"
      else
        "#{person_name} updated Assignment field suggestions for #{assignment_title} " \
          "(Position #{position_name}):"
      end

    lines = changes.map do |key, change|
      label = FIELD_LABELS[key]
      "• #{label}: #{format_value(change[:to])}"
    end

    ([header] + lines).join("\n")
  end

  def format_value(value)
    case value
    when nil
      "(cleared)"
    when Array
      return "(none)" if value.empty?

      value.map { |row| Array(row).first.to_s.truncate(120) }.join(" | ")
    else
      str = value.to_s
      str.strip.empty? ? "(cleared)" : str.truncate(500)
    end
  end

  def normalize_text(value)
    str = value.to_s
    str.strip.empty? ? nil : str
  end
end
