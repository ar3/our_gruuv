# frozen_string_literal: true

class StartHere::Widgets::ObservationsInvolvingMeWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "observations_involving_me",
    group: "About Me",
    icon: "bi-person",
    selection_title: "OGO's involving me",
    selection_description: "Observations and OGOs that involve you.",
    label: "OGO's involving me",
    path: ->(c) {
      c.view.organization_observations_path(c.organization, involving_teammate_id: c.company_teammate&.id)
    },
    description: "Observations and OGOs that involve you.",
    button_label: "View OGOs involving me"
  }.freeze
end
