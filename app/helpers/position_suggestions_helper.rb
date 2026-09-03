# frozen_string_literal: true

module PositionSuggestionsHelper
  def position_suggestion_department_label(position)
    position.title&.department&.name.presence || "Company-wide"
  end

  # Relative time with absolute timestamp (viewer timezone) on hover.
  def position_suggestion_relative_time(time, viewer: nil)
    return "" if time.blank?

    viewer ||= current_person if respond_to?(:current_person)
    absolute = format_time_in_user_timezone(time, viewer)
    relative =
      if time > Time.current
        "in #{time_ago_in_words(time)}"
      else
        "#{time_ago_in_words(time)} ago"
      end

    tag.span(relative, title: absolute, data: { bs_toggle: "tooltip", bs_title: absolute })
  end

  def position_suggestion_round_step_icon(state)
    case state
    when :done
      tag.i(class: "bi bi-check-circle-fill text-success me-1", aria: { hidden: true })
    when :current
      tag.i(class: "bi bi-arrow-right-circle-fill text-primary me-1", aria: { hidden: true })
    else
      tag.i(class: "bi bi-circle text-muted me-1", aria: { hidden: true })
    end
  end

  # Hover preview for assignment titles on the position suggestions show page.
  def position_suggestion_assignment_popover_html(assignment)
    parts = []

    if assignment.tagline.present?
      parts << tag.h6("Description", class: "fw-semibold mb-1")
      parts << tag.div(class: "markdown-content small mb-3") { render_markdown(assignment.tagline) }
    end

    if assignment.assignment_outcomes.any?
      parts << tag.h6("Outcomes", class: "fw-semibold mb-1")
      outcomes_html = safe_join(
        assignment.assignment_outcomes.map do |outcome|
          tag.div(class: "markdown-content small mb-2") { render_markdown(outcome.description) }
        end
      )
      parts << tag.div(class: "mb-3") { outcomes_html }
    elsif assignment.tagline.blank?
      parts << tag.p("No description or outcomes documented yet.", class: "small text-muted mb-3")
    end

    parts << tag.h6("Required activities", class: "fw-semibold mb-1")
    if assignment.required_activities.present?
      parts << tag.div(class: "markdown-content small mb-3") { render_markdown(assignment.required_activities) }
    else
      parts << tag.p("No required activities documented.", class: "small text-muted mb-3")
    end

    if assignment.handbook.present?
      parts << tag.p(class: "small text-muted mb-0 border-top pt-2") do
        safe_join(
          [
            tag.i(class: "bi bi-book me-1"),
            "This assignment has handbook content. Visit the assignment page to read the handbook."
          ]
        )
      end
    end

    tag.div(class: "text-start") { safe_join(parts) }
  end

  def position_suggestion_ability_description_popover_html(ability)
    if ability.description.present?
      tag.div(class: "text-start markdown-content small") { render_markdown(ability.description) }
    else
      tag.p("No ability description.", class: "small text-muted mb-0")
    end
  end

  # Optgroups for Assignment selects: Company-wide first, then departments by name;
  # titles sorted within each group. Mirrors Assignments index grouping.
  def assignments_grouped_options_for_select(assignments, selected_id = nil)
    return "" if assignments.blank?

    grouped = assignments.group_by(&:department)
    ordered_keys = grouped.keys.sort_by { |dept| dept ? [1, dept.display_name.to_s.downcase] : [0, ""] }

    options = ordered_keys.map do |department|
      label =
        if department
          department_hierarchy_display(department).presence || department.display_name
        else
          "Company-wide"
        end
      choices = grouped[department].sort_by { |a| a.title.to_s.downcase }.map { |a| [a.title, a.id] }
      [label, choices]
    end

    grouped_options_for_select(options, selected_id)
  end

  # Disclosure control for suggestion collapse panels (chevron + link styling, not a primary action).
  def position_suggestion_collapse_toggle(label:, collapse_id:, expanded:, chevron_position: :left, subtle: false)
    chevron_margin = chevron_position == :right ? "ms-1" : "me-1"
    chevrons = [
      tag.i(class: "bi bi-chevron-down collapsed #{chevron_margin}", aria: { hidden: true }),
      tag.i(class: "bi bi-chevron-up not-collapsed #{chevron_margin}", aria: { hidden: true })
    ]
    label_span = tag.span(label)
    parts = chevron_position == :right ? [label_span, *chevrons] : [*chevrons, label_span]

    tag.button(
      type: "button",
      class: ["btn btn-link btn-sm px-0 text-decoration-none", ("text-muted" if subtle)].compact.join(" "),
      data: { bs_toggle: "collapse", bs_target: "##{collapse_id}" },
      aria: { expanded: expanded ? "true" : "false", controls: collapse_id }
    ) do
      safe_join(parts)
    end
  end

  def position_suggestion_processed_row_classes(row)
    milestone = row.milestone
    if milestone&.accepted?
      "border-success bg-light"
    elsif milestone&.rejected?
      "border-danger bg-light"
    else
      "bg-light"
    end
  end

  # Linked label for process accordion rows (open + processed).
  def position_suggestion_process_row_label(organization, row)
    case row.kind
    when :free_text
      position_suggestion_free_text_process_label(organization, row.comment)
    when :milestone
      position_suggestion_milestone_process_label(organization, row.milestone)
    when :assignment_draft
      position_suggestion_assignment_draft_process_label(organization, row.assignment_draft)
    when :assignment_link
      position_suggestion_assignment_link_process_label(organization, row.assignment_link)
    else
      row.label
    end
  end

  def position_suggestion_process_row_outcome(organization, row)
    milestone = row.milestone
    if milestone&.accepted?
      relative = position_suggestion_relative_time(milestone.processed_at)
      who = position_suggestion_teammate_name_link(organization, milestone.processed_by)
      return safe_join(["Accepted and applied by ", who, " ", relative])
    end
    if milestone&.rejected?
      relative = position_suggestion_relative_time(milestone.processed_at)
      who = position_suggestion_teammate_name_link(organization, milestone.processed_by)
      return safe_join(["Rejected by ", who, " ", relative])
    end

    comment = row.comment
    return tag.span("Processed", class: "text-muted") unless comment&.resolved?

    relative = position_suggestion_relative_time(comment.resolved_at)
    safe_join(["Resolved ", relative], " ")
  end

  private

  def position_suggestion_free_text_process_label(organization, comment)
    return "Comment" if comment.blank?

    author = position_suggestion_person_name_link(organization, comment.creator)
    target = position_suggestion_commentable_label_html(organization, comment.commentable)
    safe_join(["Comment by ", author, " on ", target])
  end

  def position_suggestion_milestone_process_label(organization, milestone)
    return "Milestone" if milestone.blank?

    who = position_suggestion_teammate_name_link(organization, milestone.last_modified_by)
    ability = position_suggestion_ability_name_link(organization, position_suggestion_ability_for_milestone(milestone))
    assignment = position_suggestion_assignment_or_position_link(organization, milestone)
    level = milestone.suggested_milestone_level
    level_verb = position_suggestion_milestone_level_verb(level)

    safe_join(
      [
        who, ": ", ability, " at least Milestone #{level} (#{level_verb}) for ", assignment
      ]
    )
  end

  def position_suggestion_assignment_draft_process_label(organization, draft)
    return "Assignment field changes" if draft.blank?

    who = position_suggestion_teammate_name_link(organization, draft.last_modified_by)
    assignment = position_suggestion_assignment_name_link(organization, draft.source_assignment)
    safe_join([who, ": field changes for Assignment ", assignment])
  end

  def position_suggestion_assignment_link_process_label(organization, link)
    return "Assignment association" if link.blank?

    who = position_suggestion_teammate_name_link(organization, link.last_modified_by)
    assignment = position_suggestion_assignment_name_link(organization, link.assignment)
    case link.action
    when "add"
      safe_join([who, ": add Assignment ", assignment, " (#{link.assignment_type})"])
    when "remove"
      safe_join([who, ": remove Assignment ", assignment])
    else
      safe_join([who, ": update association for Assignment ", assignment, " (#{link.assignment_type})"])
    end
  end

  def position_suggestion_commentable_label_html(organization, commentable)
    case commentable
    when Position
      "Position #{commentable.display_name}"
    when Assignment
      safe_join(["Assignment ", position_suggestion_assignment_name_link(organization, commentable)])
    when Ability
      safe_join(["Ability ", position_suggestion_ability_name_link(organization, commentable)])
    else
      commentable.class.name
    end
  end

  def position_suggestion_assignment_or_position_link(organization, milestone)
    case milestone.milestoneable
    when AssignmentAbility
      position_suggestion_assignment_name_link(organization, milestone.milestoneable.assignment)
    else
      milestone.position_suggestion&.position&.display_name || "Position"
    end
  end

  def position_suggestion_ability_for_milestone(milestone)
    case milestone.milestoneable
    when AssignmentAbility, PositionAbility
      milestone.milestoneable.ability
    when Ability
      milestone.milestoneable
    end
  end

  def position_suggestion_milestone_level_verb(level)
    {
      1 => "Demonstrated",
      2 => "Advanced",
      3 => "Expert",
      4 => "Coach",
      5 => "Industry-Recognized"
    }[level.to_i] || "Unknown"
  end

  def position_suggestion_teammate_name_link(organization, company_teammate)
    name = company_teammate&.person&.casual_name || "Someone"
    return name if company_teammate.blank? || organization.blank?

    link_to name, internal_organization_company_teammate_path(organization, company_teammate), class: "text-decoration-none"
  end

  def position_suggestion_person_name_link(organization, person)
    name = person&.casual_name || "Someone"
    return name if person.blank? || organization.blank?

    teammate = CompanyTeammate.find_by(person: person, organization: organization)
    return name unless teammate

    link_to name, internal_organization_company_teammate_path(organization, teammate), class: "text-decoration-none"
  end

  def position_suggestion_assignment_name_link(organization, assignment)
    title = assignment&.title.presence || "Assignment"
    return title if assignment.blank? || organization.blank?

    link_to title, organization_assignment_path(organization, assignment), class: "text-decoration-none"
  end

  def position_suggestion_ability_name_link(organization, ability)
    name = ability&.name.presence || "Ability"
    return name if ability.blank? || organization.blank?

    link_to name, organization_ability_path(organization, ability), class: "text-decoration-none"
  end
end
