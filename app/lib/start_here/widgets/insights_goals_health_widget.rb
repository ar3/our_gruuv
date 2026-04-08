# frozen_string_literal: true

class StartHere::Widgets::InsightsGoalsHealthWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "insights_goals_health",
    group: "Insights",
    icon: "bi-heart-pulse",
    selection_title: "Goals Health",
    selection_description: "Goals health across employees.",
    label: "Goals Health",
    path: ->(c) { c.view.organization_goals_health_path(c.organization) },
    description: "Goals health across employees.",
    button_label: "Goals Health"
  }.freeze
end
