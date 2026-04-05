# frozen_string_literal: true

class StartHere::Widgets::AboutManageProfileWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "about_manage_profile",
    group: "About Me",
    icon: "bi-gear",
    selection_title: "Manage Profile Mode",
    selection_description: "Edit profile and teammate settings.",
    label: "Manage Profile Mode",
    path: ->(c) { c.view.organization_company_teammate_path(c.organization, c.company_teammate) },
    description: "Edit profile and teammate settings.",
    button_label: "Manage Profile Mode"
  }.freeze
end
