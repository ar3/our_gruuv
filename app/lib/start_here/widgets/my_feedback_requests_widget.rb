# frozen_string_literal: true

class StartHere::Widgets::MyFeedbackRequestsWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "my_feedback_requests",
    group: "About Me",
    icon: "bi-chat-dots",
    selection_title: "My Feedback Requests",
    selection_description: "Feedback requests assigned to you.",
    label: "My Feedback Requests",
    path: ->(c) { c.view.organization_feedback_requests_path(c.organization) },
    description: "Feedback requests assigned to you.",
    button_label: "Open Feedback Requests"
  }.freeze
end
