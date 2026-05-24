# frozen_string_literal: true

class StartHere::Widgets::MyCheckInWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "my_check_in",
    group: "About Me",
    icon: "bi-chat-square-text",
    selection_title: I18n.t("terminology.start_here_clarity_check_in_status"),
    selection_description: I18n.t("terminology.start_here_clarity_check_in_status_description"),
    label: I18n.t("terminology.start_here_clarity_check_in_status"),
    path: ->(c) { c.view.organization_company_teammate_check_ins_path(c.organization, c.company_teammate) },
    description: nil,
    button_label: I18n.t("terminology.start_here_open_clarity_check_ins")
  }.freeze

  def dashboard_content
    view.render(
      partial: "organizations/start_here/widget_dashboards/check_in_status_dashboard",
      locals: { context: context },
      formats: [ :html ]
    )
  end
end
