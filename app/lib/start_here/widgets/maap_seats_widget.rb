# frozen_string_literal: true

class StartHere::Widgets::MaapSeatsWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "maap_seats",
    group: "Admin",
    icon: "bi-briefcase",
    selection_title: "Seats",
    selection_description: "Seats catalog.",
    label: "Seats",
    path: ->(c) { c.view.organization_seats_path(c.organization) },
    description: "Seats catalog.",
    button_label: "Seats"
  }.freeze
end
