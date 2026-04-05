# frozen_string_literal: true

class StartHere::Widgets::InsightsFeedbackRequestsWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "insights_feedback_requests",
    group: "Insights",
    icon: "bi-chat-square-text",
    selection_title: "Feedback Requests Insights",
    selection_description: "Insights for feedback requests.",
    label: "Feedback Requests Insights",
    path: ->(c) { c.view.organization_insights_feedback_requests_path(c.organization) },
    description: "Insights for feedback requests.",
    button_label: "Open Insights"
  }.freeze
end
