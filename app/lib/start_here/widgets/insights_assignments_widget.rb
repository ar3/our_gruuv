# frozen_string_literal: true

class StartHere::Widgets::InsightsAssignmentsWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "insights_assignments",
    group: "Insights",
    icon: "bi-list-check",
    selection_title: "Assignments Insights",
    selection_description: "Assignment insights.",
    label: "Assignments Insights",
    path: ->(c) { c.view.organization_insights_assignments_path(c.organization) },
    description: "Assignment insights.",
    button_label: "Open Insights"
  }.freeze
end
