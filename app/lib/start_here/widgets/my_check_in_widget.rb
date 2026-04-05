# frozen_string_literal: true

class StartHere::Widgets::MyCheckInWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "my_check_in",
    group: "About Me",
    icon: "bi-chat-square-text",
    selection_title: "Check-In",
    selection_description: "Your check-in sessions and timeline.",
    label: "Check-In",
    path: ->(c) { c.view.organization_company_teammate_check_ins_path(c.organization, c.company_teammate) },
    description: "Your check-in sessions and timeline.",
    button_label: "Check-In"
  }.freeze
end
