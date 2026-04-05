# frozen_string_literal: true

class StartHere::Widgets::AllObservationsWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "all_observations",
    group: "Observations (OGO)",
    icon: "bi-list-ul",
    selection_title: "All observations",
    selection_description: "Browse all observations in the organization.",
    label: "All observations",
    path: ->(c) { c.view.organization_observations_path(c.organization) },
    description: "Browse all observations in the organization.",
    button_label: "View all observations"
  }.freeze
end
