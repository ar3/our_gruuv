# frozen_string_literal: true

class StartHere::Widgets::BetaCheckInHistoryWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "beta_check_in_history",
    group: "About Me",
    icon: "bi-table",
    selection_title: "Check-In Status",
    selection_description: "Recent check-in status and history.",
    label: "Check-In Status",
    path: ->(c) { c.view.review_most_recent_organization_company_teammate_check_ins_path(c.organization, c.company_teammate) },
    description: "Recent check-in status and history.",
    button_label: "Check-In Status"
  }.freeze
end
