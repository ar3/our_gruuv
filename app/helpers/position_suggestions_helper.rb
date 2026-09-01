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

  def position_suggestion_process_row_outcome(row)
    comment = row.comment
    return tag.span("Processed", class: "text-muted") unless comment&.resolved?

    relative = position_suggestion_relative_time(comment.resolved_at)
    safe_join(["Resolved ", relative], " ")
  end
end
