# frozen_string_literal: true

class StartHere::Widgets::KudosWallWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "kudos_wall",
    group: "Observations (OGO)",
    icon: "bi-gift",
    selection_title: "Kudos Wall",
    selection_description: "Recognition and kudos shared across the organization.",
    label: ->(c) { "#{c.org_display_name} Kudos" },
    path: ->(c) {
      c.view.organization_observations_path(
        c.organization,
        privacy: %w[public_to_company public_to_world],
        spotlight: "most_observed",
        view: "wall"
      )
    },
    description: "Recognition and kudos shared across the organization.",
    button_label: ->(c) { "View #{c.org_display_name} Kudos" }
  }.freeze
end
