# frozen_string_literal: true

# One system thread per Assignment link proposal (suggestion_thread_subject = link).
# First save: diff vs live edge (or describe add/remove). Later saves: diff vs previous bag.
class PositionSuggestions::NotifyAssignmentLinkSuggestionService
  FIELD_LABELS = {
    "action" => "Action",
    "assignment_type" => "Type",
    "min_estimated_energy" => "Min energy",
    "max_estimated_energy" => "Max energy"
  }.freeze

  ACTION_LABELS = {
    "add" => "add to Position",
    "update" => "update association",
    "remove" => "remove from Position"
  }.freeze

  def self.call(suggestion:, link:, modified_by:, first_save:, previous_snapshot:)
    new(
      suggestion: suggestion,
      link: link,
      modified_by: modified_by,
      first_save: first_save,
      previous_snapshot: previous_snapshot
    ).call
  end

  def initialize(suggestion:, link:, modified_by:, first_save:, previous_snapshot:)
    @suggestion = suggestion
    @link = link
    @modified_by = modified_by
    @first_save = first_save
    @previous_snapshot = previous_snapshot
  end

  def call
    changes = @first_save ? diff_against_live : diff_against_previous
    body = build_body(changes)
    assignment = @link.assignment
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
        suggestion_thread_subject: @link
      )
    end
  end

  private

  def existing_root_comment(assignment)
    Comment
      .for_position_suggestion(@suggestion)
      .for_commentable(assignment)
      .for_suggestion_thread_subject(@link)
      .root_comments
      .ordered
      .first
  end

  def diff_against_live
    after = @link.edge_snapshot
    before = live_baseline_snapshot
    return after_as_changes(after) if before.nil?

    diff_snapshots(before, after)
  end

  def live_baseline_snapshot
    return nil if @link.add?

    pa = @suggestion.position.position_assignments.find_by(assignment_id: @link.assignment_id)
    return nil unless pa

    {
      "action" => "update",
      "assignment_type" => pa.assignment_type.to_s,
      "min_estimated_energy" => pa.min_estimated_energy,
      "max_estimated_energy" => pa.max_estimated_energy
    }
  end

  def after_as_changes(after)
    after.each_with_object({}) do |(key, value), changes|
      changes[key] = { from: nil, to: value }
    end
  end

  def diff_against_previous
    return diff_against_live if @previous_snapshot.blank?

    diff_snapshots(@previous_snapshot, @link.edge_snapshot)
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
    assignment_title = @link.assignment.title
    position_name = @suggestion.position.display_name
    action = @link.action

    header =
      if @first_save
        case action
        when "add"
          "#{person_name} suggested adding Assignment #{assignment_title} to Position #{position_name}:"
        when "remove"
          "#{person_name} suggested removing Assignment #{assignment_title} from Position #{position_name} " \
            "(type and energy kept until accept):"
        else
          "#{person_name} suggested Assignment association changes for #{assignment_title} " \
            "(Position #{position_name}):"
        end
      else
        "#{person_name} updated Assignment association suggestions for #{assignment_title} " \
          "(Position #{position_name}):"
      end

    lines = changes.map do |key, change|
      label = FIELD_LABELS[key]
      "• #{label}: #{format_value(key, change[:to])}"
    end

    if lines.empty?
      lines = [
        "• Type: #{@link.assignment_type}",
        "• Energy: #{@link.energy_range_display}"
      ]
    end

    ([header] + lines).join("\n")
  end

  def format_value(key, value)
    case key
    when "action"
      ACTION_LABELS[value.to_s] || value.to_s.presence || "(cleared)"
    when "min_estimated_energy", "max_estimated_energy"
      value.nil? ? "(cleared)" : "#{value}%"
    else
      value.to_s.presence || "(cleared)"
    end
  end
end
