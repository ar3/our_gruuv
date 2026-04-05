# frozen_string_literal: true

class StartHere::Widgets::MaapPositionsWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "maap_positions",
    group: "Admin",
    icon: "bi-briefcase-fill",
    selection_title: "Positions",
    selection_description: "Organization positions.",
    label: "Positions",
    path: ->(c) { c.view.organization_positions_path(c.organization) },
    description: "Organization positions.",
    button_label: "Positions"
  }.freeze
end
