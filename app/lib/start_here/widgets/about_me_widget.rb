# frozen_string_literal: true

class StartHere::Widgets::AboutMeWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "about_me",
    group: "About Me",
    icon: "bi-person",
    selection_title: "About Me",
    selection_description: "Your check-ins, goals, observations, and growth in one place.",
    label: ->(c) { "About #{c.casual_name}" },
    path: ->(c) { c.view.about_me_organization_company_teammate_path(c.organization, c.company_teammate) },
    description: "Your check-ins, goals, observations, and growth in one place.",
    button_label: ->(c) { "Go to About #{c.casual_name}" }
  }.freeze
end
