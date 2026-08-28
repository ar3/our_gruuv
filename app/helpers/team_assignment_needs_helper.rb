# frozen_string_literal: true

module TeamAssignmentNeedsHelper
  def team_assignment_need_type_label(need_type)
    case need_type
    when "required"
      "Required"
    when "nice_to_have"
      "Nice-to-have"
    else
      need_type.to_s.humanize
    end
  end

  def team_assignment_coverer_discrepancy_badges(status)
    badges = []
    if status.missing_tenure
      badges << content_tag(:span, "No active assignment", class: "badge bg-warning text-dark")
    end
    if status.not_team_member
      badges << content_tag(:span, "Not on team", class: "badge bg-secondary")
    end
    safe_join(badges, " ")
  end
end
