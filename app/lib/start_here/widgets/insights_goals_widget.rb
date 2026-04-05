# frozen_string_literal: true

class StartHere::Widgets::InsightsGoalsWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "insights_goals",
    group: "Insights",
    icon: "bi-bullseye",
    selection_title: "Goals Insights",
    selection_description: "Goal insights.",
    label: "Goals Insights",
    path: ->(c) { c.view.organization_insights_goals_path(c.organization) },
    description: "Goal insights.",
    button_label: "Open Insights"
  }.freeze
end
