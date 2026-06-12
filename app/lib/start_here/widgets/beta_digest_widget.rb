# frozen_string_literal: true

class StartHere::Widgets::BetaDigestWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "beta_digest",
    group: "Beta",
    icon: "bi-bell",
    selection_title: "Notifications",
    selection_description: "Notification preferences.",
    label: "Notifications",
    path: ->(c) { c.view.organization_company_teammate_notifications_path(c.organization, c.view.current_company_teammate) },
    description: "Notification preferences.",
    button_label: "Notification settings"
  }.freeze
end
