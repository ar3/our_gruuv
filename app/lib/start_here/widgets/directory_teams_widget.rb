# frozen_string_literal: true

class StartHere::Widgets::DirectoryTeamsWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "directory_teams",
    group: "Directory",
    icon: "bi-people",
    selection_title: "Teams",
    selection_description: "Organization teams.",
    label: "Teams",
    path: ->(c) { c.view.organization_teams_path(c.organization) },
    description: "Organization teams.",
    button_label: "Teams"
  }.freeze
end
