# frozen_string_literal: true

# Builds chronological round summary events and MAAP "Process all suggestions" rows.
class PositionSuggestions::RoundSummaryBuilder
  Event = Struct.new(:at, :kind, :person, :text, keyword_init: true)
  ProcessRow = Struct.new(
    :kind, :label, :anchor, :comment, :milestone, :assignment_draft, :assignment_link, :resolved,
    keyword_init: true
  )

  def self.call(suggestion:)
    new(suggestion: suggestion).call
  end

  def initialize(suggestion:)
    @suggestion = suggestion
  end

  def call
    {
      timeline: build_timeline,
      process_rows: build_process_rows
    }
  end

  private

  def build_timeline
    events = []
    events << started_event
    events.concat(joined_events)
    events.concat(free_text_comment_events)
    events.concat(milestone_suggestion_events)
    events.concat(assignment_draft_events)
    events.concat(assignment_link_events)
    events.compact.sort_by { |e| [e.at || Time.zone.at(0), e.kind.to_s] }
  end

  def started_event
    opener = @suggestion.opened_by&.person
    Event.new(
      at: @suggestion.created_at,
      kind: :started,
      person: opener,
      text: "Suggestion round started"
    )
  end

  def joined_events
    @suggestion.participants.includes(company_teammate: :person).filter_map do |participant|
      person = participant.company_teammate&.person
      next unless person

      Event.new(
        at: participant.created_at,
        kind: :joined,
        person: person,
        text: "#{person.casual_name} began thinking about suggestions"
      )
    end
  end

  def free_text_comment_events
    @suggestion.free_text_root_comments.includes(:creator, :commentable).map do |comment|
      object_name = commentable_label(comment.commentable)
      Event.new(
        at: comment.created_at,
        kind: :comment,
        person: comment.creator,
        text: "#{comment.creator.casual_name} added comment on #{object_name}"
      )
    end
  end

  def milestone_suggestion_events
    milestones = @suggestion.milestones.includes(
      :last_modified_by,
      milestoneable: [:ability, :assignment]
    )

    milestones.flat_map do |milestone|
      version_events = version_events_for(milestone)
      version_events.presence || [current_milestone_event(milestone)]
    end
  end

  def version_events_for(milestone)
    return [] unless milestone.respond_to?(:versions)

    milestone.versions.reorder(created_at: :asc, id: :asc).filter_map do |version|
      level = level_from_version(version, milestone)
      next unless level

      person = person_from_version(version) || milestone.last_modified_by&.person
      next unless person

      Event.new(
        at: version.created_at,
        kind: :milestone,
        person: person,
        text: milestone_event_text(person, milestone, level)
      )
    end
  end

  def current_milestone_event(milestone)
    person = milestone.last_modified_by&.person
    return nil unless person

    Event.new(
      at: milestone.updated_at,
      kind: :milestone,
      person: person,
      text: milestone_event_text(person, milestone, milestone.suggested_milestone_level)
    )
  end

  def milestone_event_text(person, milestone, level)
    ability_name = ability_name_for(milestone)
    assignment_name = assignment_name_for(milestone)
    level_verb = milestone_level_display(level)

    "#{person.casual_name} suggested #{ability_name} must be at least Milestone #{level} " \
      "(#{level_verb}) to be qualified for #{assignment_name}"
  end

  def level_from_version(version, milestone)
    changes = version.changeset
    if changes.is_a?(Hash) && changes["suggested_milestone_level"]
      Array(changes["suggested_milestone_level"]).last
    elsif version.event == "create"
      milestone.suggested_milestone_level
    else
      reified = version.reify
      reified&.suggested_milestone_level || milestone.suggested_milestone_level
    end
  rescue StandardError
    milestone.suggested_milestone_level
  end

  def person_from_version(version)
    raw = version.whodunnit
    return nil if raw.blank?

    teammate = CompanyTeammate.find_by(id: raw.to_s)
    teammate&.person || Person.find_by(id: raw.to_s)
  end

  def ability_name_for(milestone)
    case milestone.milestoneable
    when AssignmentAbility
      milestone.milestoneable.ability&.name.presence || "Ability"
    when PositionAbility
      milestone.milestoneable.ability&.name.presence || "Ability"
    when Ability
      milestone.milestoneable.name
    else
      "Ability"
    end
  end

  def assignment_name_for(milestone)
    case milestone.milestoneable
    when AssignmentAbility
      milestone.milestoneable.assignment&.title.presence || "Assignment"
    else
      @suggestion.position.display_name
    end
  end

  def milestone_level_display(level)
    {
      1 => "Demonstrated",
      2 => "Advanced",
      3 => "Expert",
      4 => "Coach",
      5 => "Industry-Recognized"
    }[level.to_i] || "Unknown"
  end

  def commentable_label(commentable)
    case commentable
    when Position
      "Position #{commentable.display_name}"
    when Assignment
      "Assignment #{commentable.title}"
    when Ability
      "Ability #{commentable.name}"
    else
      commentable.class.name
    end
  end

  def assignment_draft_events
    @suggestion.assignment_drafts.includes(:last_modified_by, :source_assignment).filter_map do |draft|
      person = draft.last_modified_by&.person
      next unless person

      Event.new(
        at: draft.updated_at,
        kind: :assignment_draft,
        person: person,
        text: "#{person.casual_name} suggested field changes for Assignment #{draft.source_assignment.title}"
      )
    end
  end

  def assignment_link_events
    @suggestion.assignment_links.includes(:last_modified_by, :assignment).filter_map do |link|
      person = link.last_modified_by&.person
      next unless person

      Event.new(
        at: link.updated_at,
        kind: :assignment_link,
        person: person,
        text: assignment_link_event_text(person, link)
      )
    end
  end

  def assignment_link_event_text(person, link)
    title = link.assignment.title
    case link.action
    when "add"
      "#{person.casual_name} suggested adding Assignment #{title} to this Position"
    when "remove"
      "#{person.casual_name} suggested removing Assignment #{title} from this Position"
    else
      "#{person.casual_name} suggested association changes for Assignment #{title}"
    end
  end

  def build_process_rows
    rows = []

    @suggestion.free_text_root_comments.includes(:creator, :commentable).find_each do |comment|
      rows << ProcessRow.new(
        kind: :free_text,
        label: free_text_process_label(comment),
        anchor: free_text_anchor(comment),
        comment: comment,
        milestone: nil,
        assignment_draft: nil,
        assignment_link: nil,
        resolved: comment.resolved?
      )
    end

    @suggestion.milestones.includes(:last_modified_by, processed_by: :person, milestoneable: [:ability, :assignment]).find_each do |milestone|
      root = milestone_thread_root(milestone)
      rows << ProcessRow.new(
        kind: :milestone,
        label: milestone_process_label(milestone),
        anchor: milestone_anchor(milestone),
        comment: root,
        milestone: milestone,
        assignment_draft: nil,
        assignment_link: nil,
        resolved: milestone.processed? || root&.resolved?
      )
    end

    @suggestion.assignment_drafts.includes(:last_modified_by, :source_assignment).find_each do |draft|
      root = assignment_draft_thread_root(draft)
      rows << ProcessRow.new(
        kind: :assignment_draft,
        label: assignment_draft_process_label(draft),
        anchor: "assignment-#{draft.source_assignment_id}-fields",
        comment: root,
        milestone: nil,
        assignment_draft: draft,
        assignment_link: nil,
        resolved: root&.resolved?
      )
    end

    @suggestion.assignment_links.includes(:last_modified_by, :assignment).find_each do |link|
      root = assignment_link_thread_root(link)
      rows << ProcessRow.new(
        kind: :assignment_link,
        label: assignment_link_process_label(link),
        anchor: "assignment-#{link.assignment_id}-link",
        comment: root,
        milestone: nil,
        assignment_draft: nil,
        assignment_link: link,
        resolved: root&.resolved?
      )
    end

    rows
  end

  def free_text_process_label(comment)
    author = comment.creator.casual_name
    "Comment by #{author} on #{commentable_label(comment.commentable)}"
  end

  def milestone_process_label(milestone)
    person = milestone.last_modified_by&.person
    name = person&.casual_name || "Someone"
    ability_name = ability_name_for(milestone)
    assignment_name = assignment_name_for(milestone)
    level = milestone.suggested_milestone_level
    level_verb = milestone_level_display(level)

    "#{name}: #{ability_name} at least Milestone #{level} (#{level_verb}) for #{assignment_name}"
  end

  def assignment_draft_process_label(draft)
    person = draft.last_modified_by&.person
    name = person&.casual_name || "Someone"
    "#{name}: field changes for Assignment #{draft.source_assignment.title}"
  end

  def assignment_link_process_label(link)
    person = link.last_modified_by&.person
    name = person&.casual_name || "Someone"
    title = link.assignment.title
    case link.action
    when "add"
      "#{name}: add Assignment #{title} (#{link.assignment_type})"
    when "remove"
      "#{name}: remove Assignment #{title}"
    else
      "#{name}: update association for Assignment #{title} (#{link.assignment_type})"
    end
  end

  def assignment_draft_thread_root(draft)
    Comment
      .for_position_suggestion(@suggestion)
      .for_commentable(draft.source_assignment)
      .for_suggestion_thread_subject(draft)
      .root_comments
      .ordered
      .first
  end

  def assignment_link_thread_root(link)
    Comment
      .for_position_suggestion(@suggestion)
      .for_commentable(link.assignment)
      .for_suggestion_thread_subject(link)
      .root_comments
      .ordered
      .first
  end

  def free_text_anchor(comment)
    case comment.commentable
    when Position
      "position-comments"
    when Assignment
      "assignment-#{comment.commentable_id}"
    else
      "comment-#{comment.id}"
    end
  end

  def milestone_anchor(milestone)
    case milestone.milestoneable
    when AssignmentAbility
      "assignment-ability-#{milestone.milestoneable_id}"
    when PositionAbility
      "position-comments"
    else
      "position-comments"
    end
  end

  def milestone_thread_root(milestone)
    return nil unless milestone.milestoneable.is_a?(AssignmentAbility)

    assignment = milestone.milestoneable.assignment
    Comment
      .for_position_suggestion(@suggestion)
      .for_commentable(assignment)
      .for_suggestion_thread_subject(milestone.milestoneable)
      .root_comments
      .ordered
      .first
  end
end
