# frozen_string_literal: true

class StartHere::Widgets::MyCheckInWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "my_check_in",
    group: "About Me",
    icon: "bi-chat-square-text",
    selection_title: "Check-in status",
    selection_description: "How clear your check-ins are across values, assignments, and position.",
    label: "Check-in status",
    path: ->(c) { c.view.organization_company_teammate_check_ins_path(c.organization, c.company_teammate) },
    description: nil,
    button_label: "Check-In"
  }.freeze

  def dashboard_content
    view.render(
      partial: "organizations/start_here/widget_dashboards/check_in_status_dashboard",
      locals: { context: context },
      formats: [ :html ]
    )
  end
end
