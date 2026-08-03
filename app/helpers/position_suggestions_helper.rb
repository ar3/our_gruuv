# frozen_string_literal: true

module PositionSuggestionsHelper
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
end
