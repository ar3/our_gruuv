# frozen_string_literal: true

class StartHere::Widgets::AboutCompletePictureWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "about_complete_picture",
    group: "About Me",
    icon: "bi-graph-up",
    selection_title: "Active Job View",
    selection_description: "Role, assignments, and job context.",
    label: "Active Job View",
    path: ->(c) { c.view.complete_picture_organization_company_teammate_path(c.organization, c.company_teammate) },
    description: "Role, assignments, and job context.",
    button_label: "Active Job View"
  }.freeze
end
