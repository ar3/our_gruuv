# frozen_string_literal: true

class StartHere::Widgets::InsightsWhoIsDoingWhatWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "insights_who_is_doing_what",
    group: "Insights",
    icon: "bi-pie-chart",
    selection_title: "Who is doing what",
    selection_description: "Activity breakdown.",
    label: "Who is doing what",
    path: ->(c) { c.view.organization_insights_who_is_doing_what_path(c.organization) },
    description: "Activity breakdown.",
    button_label: "Open Insights"
  }.freeze
end
