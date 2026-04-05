# frozen_string_literal: true

class StartHere::Widgets::InsightsDashboardWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "insights_dashboard",
    group: "Insights",
    icon: "bi-bar-chart-line",
    selection_title: "Insights Overview Links",
    selection_description: "Charts and reports on observations, goals, check-ins, and more.",
    label: "Insights Overview Links",
    path: ->(c) { c.view.organization_insights_path(c.organization) },
    description: "Charts and reports on observations, goals, check-ins, and more.",
    button_label: "Insights Overview Links"
  }.freeze
end
