# frozen_string_literal: true

# Card title “Check-in status” in many layouts; body matches Start Here clarity table (same as my_check_in).
class StartHere::Widgets::BetaCheckInHistoryWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "beta_check_in_history",
    group: "About Me",
    icon: "bi-table",
    selection_title: "Check-in status",
    selection_description: "How clear your check-ins are across values, assignments, and position.",
    label: "Check-in status",
    path: ->(c) { c.view.review_most_recent_organization_company_teammate_check_ins_path(c.organization, c.company_teammate) },
    description: nil,
    button_label: "Check-in history"
  }.freeze

  def dashboard_content
    view.render(
      partial: "organizations/start_here/widget_dashboards/check_in_status_dashboard",
      locals: { context: context },
      formats: [ :html ]
    )
  end
end
