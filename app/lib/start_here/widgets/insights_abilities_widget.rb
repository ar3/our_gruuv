# frozen_string_literal: true

class StartHere::Widgets::InsightsAbilitiesWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "insights_abilities",
    group: "Insights",
    icon: "bi-award",
    selection_title: "Abilities Insights",
    selection_description: "Ability insights.",
    label: "Abilities Insights",
    path: ->(c) { c.view.organization_insights_abilities_path(c.organization) },
    description: "Ability insights.",
    button_label: "Open Insights"
  }.freeze
end
