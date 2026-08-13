# frozen_string_literal: true

class StartHere::Widgets::MyFeedbackRequestsWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "my_feedback_requests",
    group: "About Me",
    icon: "bi-chat-dots",
    selection_title: "My Feedback Requests",
    selection_description: "Feedback requests waiting on you, about you, or that you created.",
    label: "My Feedback Requests",
    path: ->(c) {
      c.view.ogos_feedback_requests_organization_company_teammate_path(c.organization, "me")
    },
    description: "Feedback requests waiting on you, about you, or that you created.",
    button_label: "Open Feedback Requests"
  }.freeze
end
