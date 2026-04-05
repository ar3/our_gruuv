# frozen_string_literal: true

class StartHere::Widgets::MaapAssignmentsWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "maap_assignments",
    group: "Admin",
    icon: "bi-list-check",
    selection_title: "Assignments",
    selection_description: "Seat assignments.",
    label: "Assignments",
    path: ->(c) { c.view.organization_assignments_path(c.organization) },
    description: "Seat assignments.",
    button_label: "Assignments"
  }.freeze
end
