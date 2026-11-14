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
      key: :milestones_health,
      label: "Milestones",
      icon: "bi-trophy",
      path_name: :organization_milestones_health_path,
      policy_method: :milestones_health?
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

  def goals_health_other_actions(organization, manager_id:, teammate_count:)
    [
      health_dashboard_refresh_all_action(
        path: organization_goals_health_refresh_all_path(organization, manager_id: manager_id),
        count: teammate_count
      ),
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

  def observations_health_other_actions(organization, manager_id:, teammate_count:)
    [
      health_dashboard_refresh_all_action(
        path: organization_observations_health_refresh_all_path(organization, manager_id: manager_id),
        count: teammate_count,
        title_when_enabled: "Queue Gruuv Health and mix refresh for everyone in this view"
      ),
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

  def check_ins_health_other_actions(organization, manager_id:, teammate_count:)
    actions = [
      health_dashboard_refresh_all_action(
        path: organization_check_ins_health_refresh_all_path(organization, manager_id: manager_id),
        count: teammate_count
      )
    ]

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

  def milestones_health_other_actions(organization, manager_id:, teammate_count:)
    [
      health_dashboard_refresh_all_action(
        path: organization_milestones_health_refresh_all_path(organization, manager_id: manager_id),
        count: teammate_count
      ),
      {
        label: "Download employees milestones summary (CSV)",
        path: organization_milestones_health_employee_summary_export_path(organization, manager_id: manager_id),
        icon: "bi-download"
      }
    ]
  end

  def assignments_health_other_actions(organization, refreshable_count:)
    [
      health_dashboard_counted_refresh_action(
        label_base: "Refresh missing & stale",
        path: organization_assignments_health_refresh_missing_and_stale_path(organization),
        count: refreshable_count,
        title_when_empty: "Nothing missing or stale right now"
      )
    ]
  end

  def values_health_other_actions(organization, refreshable_count:)
    [
      health_dashboard_counted_refresh_action(
        label_base: "Refresh missing & stale",
        path: organization_values_health_refresh_missing_and_stale_path(organization),
        count: refreshable_count,
        title_when_empty: "Nothing missing or stale right now"
      )
    ]
  end

  def abilities_health_other_actions(organization, refreshable_count:)
    [
      health_dashboard_counted_refresh_action(
        label_base: "Refresh missing & stale",
        path: organization_abilities_health_refresh_missing_and_stale_path(organization),
        count: refreshable_count,
        title_when_empty: "Nothing missing or stale right now",
        title_when_enabled: "Ability Expectation Alignment scoring is coming soon"
      )
    ]
  end

  def positions_health_other_actions(organization, title_count:)
    [
      health_dashboard_counted_refresh_action(
        label_base: "Refresh all",
        path: organization_positions_health_refresh_all_path(organization),
        count: title_count,
        title_when_empty: "No titles to refresh",
        title_when_enabled: "Recalculate Title EAS for every unarchived title"
      )
    ]
  end

  def departments_health_other_actions(organization, record_count:)
    [
      health_dashboard_counted_refresh_action(
        label_base: "Refresh all",
        path: organization_departments_health_refresh_all_path(organization),
        count: record_count,
        title_when_empty: "Nothing to refresh",
        title_when_enabled: "Recalculate Title, Position, and Assignment EAS for this organization"
      )
    ]
  end

  private

  def health_dashboard_refresh_all_action(path:, count:, title_when_enabled: nil)
    health_dashboard_counted_refresh_action(
      label_base: "Refresh all",
      path: path,
      count: count,
      title_when_empty: "No teammates in this view",
      title_when_enabled: title_when_enabled || "Queue Gruuv Health refresh for everyone in this view"
    )
  end

  def health_dashboard_counted_refresh_action(label_base:, path:, count:, title_when_empty:, title_when_enabled: nil)
    {
      label: count.positive? ? "#{label_base} (#{count})" : label_base,
      path: path,
      icon: "bi-arrow-clockwise",
      method: :post,
      disabled: count.zero?,
      title: (count.zero? ? title_when_empty : title_when_enabled)
    }
  end
end
