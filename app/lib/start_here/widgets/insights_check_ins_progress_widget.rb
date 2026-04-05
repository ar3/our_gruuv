# frozen_string_literal: true

class StartHere::Widgets::InsightsCheckInsProgressWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "insights_check_ins_progress",
    group: "Insights",
    icon: "bi-bar-chart-steps",
    selection_title: "Check-ins Progress",
    selection_description: "Check-in progress over time.",
    label: "Check-ins Progress",
    path: ->(c) { c.view.organization_insights_check_ins_progress_path(c.organization) },
    description: "Check-in progress over time.",
    button_label: "Check-ins Progress"
  }.freeze
end
