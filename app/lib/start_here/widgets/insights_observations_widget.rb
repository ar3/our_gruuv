# frozen_string_literal: true

class StartHere::Widgets::InsightsObservationsWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "insights_observations",
    group: "Insights",
    icon: "bi-eye",
    selection_title: "Observations Insights",
    selection_description: "Insights for observations.",
    label: "Observations Insights",
    path: ->(c) { c.view.organization_insights_observations_path(c.organization) },
    description: "Insights for observations.",
    button_label: "Open Insights"
  }.freeze
end
