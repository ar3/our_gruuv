# frozen_string_literal: true

module TeammateSwitcherHelper
  # Browser tab title aligned with header UX: "Casual Name - Page Label"
  def teammate_context_page_title(teammate, page_label)
    "#{teammate.person.casual_name} - #{page_label}"
  end

  # Keep the selected OGOs tab when switching teammates in the title dropdown.
  def ogos_tab_path_for_teammate(organization, active_tab)
    case active_tab
    when :from
      ->(tm) { ogos_from_organization_company_teammate_path(organization, teammate_route_param(tm)) }
    when :feedback_requests
      ->(tm) { ogos_feedback_requests_organization_company_teammate_path(organization, teammate_route_param(tm)) }
    when :source_from_slack
      ->(tm) { ogos_source_from_slack_organization_company_teammate_path(organization, teammate_route_param(tm)) }
    else
      ->(tm) { ogos_organization_company_teammate_path(organization, teammate_route_param(tm)) }
    end
  end
end
