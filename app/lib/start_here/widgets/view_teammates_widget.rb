# frozen_string_literal: true

class StartHere::Widgets::ViewTeammatesWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "view_teammates",
    group: "Directory",
    icon: "bi-people",
    selection_title: "View Teammates",
    selection_description: "Directory of teammates.",
    label: "View Teammates",
    path: ->(c) { c.view.organization_employees_path(c.organization, spotlight: "teammate_tenures") },
    description: "Directory of teammates.",
    button_label: "View Teammates"
  }.freeze
end
