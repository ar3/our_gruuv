# frozen_string_literal: true

class StartHere::Widgets::BetaMyGrowthWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "beta_my_growth",
    group: "About Me",
    icon: "bi-seedling",
    selection_title: "My Growth",
    selection_description: "Growth experiences, abilities, goals, and position change.",
    label: "My Growth",
    path: ->(c) { c.view.my_growth_experiences_organization_company_teammate_path(c.organization, c.company_teammate) },
    description: "Growth experiences, abilities, goals, and position change.",
    button_label: "My Growth"
  }.freeze
end
