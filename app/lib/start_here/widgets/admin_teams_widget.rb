# frozen_string_literal: true

class StartHere::Widgets::AdminTeamsWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "admin_teams",
    group: "Admin",
    icon: "bi-people",
    selection_title: "Teams",
    selection_description: "Teams.",
    label: "Teams",
    path: ->(c) { c.view.organization_teams_path(c.organization) },
    description: "Teams.",
    button_label: "Teams"
  }.freeze
end
