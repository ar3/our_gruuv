# frozen_string_literal: true

class StartHere::Widgets::AdminSlackWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "admin_slack",
    group: "Admin",
    icon: "bi-slack",
    selection_title: "Slack Settings",
    selection_description: "Slack integration.",
    label: "Slack Settings",
    path: ->(c) { c.view.organization_slack_path(c.organization) },
    description: "Slack integration.",
    button_label: "Slack Settings"
  }.freeze
end
