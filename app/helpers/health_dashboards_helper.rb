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

  def goals_health_other_actions(organization, manager_id:)
    [
      { label: "My goals", path: organization_goals_path(organization), icon: "bi-bullseye" },
      {
        label: "Company Goal Insights",
        path: organization_insights_goals_path(organization),
        icon: "bi-bar-chart-steps"
      },
      {
        label: "Download goals (CSV)",
        path: organization_goals_health_export_path(organization, manager_id: manager_id),
        icon: "bi-download"
      },
      {
        label: "Download employees goals summary (CSV)",
        path: organization_goals_health_employee_summary_export_path(organization, manager_id: manager_id),
        icon: "bi-download"
      }
    ]
  end

  def observations_health_other_actions(organization, manager_id:)
    [
      {
        label: "Refresh all in this view",
        path: organization_observations_health_refresh_all_path(organization, manager_id: manager_id),
        icon: "bi-arrow-clockwise",
        method: :post
      },
      {
        label: "Company Observations Insights",
        path: organization_insights_observations_path(organization),
        icon: "bi-bar-chart-steps"
      },
      {
        label: "Download OGOs (CSV)",
        path: organization_observations_health_export_path(organization, manager_id: manager_id),
        icon: "bi-download"
      },
      {
        label: "Download employees observations summary (CSV)",
        path: organization_observations_health_employee_summary_export_path(organization, manager_id: manager_id),
        icon: "bi-download"
      }
    ]
  end

  def check_ins_health_other_actions(organization, manager_id:)
    actions = []

    if can_view_check_ins_health_by_manager?
      actions << {
        label: "By manager",
        path: organization_check_ins_health_by_manager_path(organization),
        icon: "bi-people"
      }
    else
      actions << {
        label: "By manager",
        path: "#",
        icon: "bi-exclamation-triangle",
        disabled: true,
        title: "You must be a manager with direct reports to view the By Manager page."
      }
    end

    actions << {
      label: "Check-ins Progress",
      path: organization_insights_check_ins_progress_path(organization),
      icon: "bi-bar-chart-steps"
    }
    actions << {
      label: "Download check-ins (CSV)",
      path: organization_check_ins_health_export_path(organization, manager_id: manager_id),
      icon: "bi-download"
    }
    actions << {
      label: "Download employee check-in summary CSV",
      path: organization_check_ins_health_employee_summary_export_path(organization, manager_id: manager_id),
      icon: "bi-download"
    }
    actions
  end
end
