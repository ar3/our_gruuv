# frozen_string_literal: true

class StartHere::Widgets::AboutSeatManagementWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "about_seat_management",
    group: "About Me",
    icon: "bi-briefcase",
    selection_title: "Seat Management Mode",
    selection_description: "Manage seat, position, and assignment details.",
    label: "Seat Management Mode",
    path: ->(c) { c.view.organization_teammate_position_path(c.organization, c.company_teammate) },
    description: "Manage seat, position, and assignment details.",
    button_label: "Seat Management Mode"
  }.freeze
end
