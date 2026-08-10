# frozen_string_literal: true

class StartHere::Widgets::AboutInternalViewWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "about_internal_view",
    group: "About Me",
    icon: "bi-people",
    selection_title: "True JD (teammate view)",
    selection_description: "Internal teammate profile and employment details.",
    label: "True JD (teammate view)",
    path: ->(c) { c.view.internal_organization_company_teammate_path(c.organization, c.company_teammate) },
    description: "Internal teammate profile and employment details.",
    button_label: "True JD (teammate view)"
  }.freeze
end
