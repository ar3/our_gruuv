# frozen_string_literal: true

module HealthDashboardsHelper
  HEALTH_DASHBOARD_PAGES = [
    {
      key: :protect_flow,
      label: "Overview/All",
      icon: "bi-shield-check",
      path_name: :organization_protect_flow_path,
      policy_method: :protect_flow?
    },
    {
      key: :check_ins_health,
      label: "Check-ins",
      icon: "bi-clipboard-check",
      path_name: :organization_check_ins_health_path,
      policy_method: :check_ins_health?
    },
    {
      key: :goals_health,
      label: "Goals",
      icon: "bi-bullseye",
      path_name: :organization_goals_health_path,
      policy_method: :goals_health?
    },
    {
      key: :observations_health,
      label: "Observations",
      icon: "bi-eye",
      path_name: :organization_observations_health_path,
      policy_method: :observations_health?
    }
  ].freeze

  def health_dashboard_switcher_pages(organization, manager_id: nil)
    manager_id = manager_id.presence || params[:manager_id]
    HEALTH_DASHBOARD_PAGES.filter_map do |page|
      next unless policy(organization).public_send(page[:policy_method])

      page.merge(path: public_send(page[:path_name], organization, manager_id: manager_id))
    end
  end

  def health_dashboard_switcher_button_class(page_key, current_key)
    base = "btn"
    page_key == current_key ? "#{base} btn-primary" : "#{base} btn-outline-primary"
  end

end
