# frozen_string_literal: true

class StartHere::Widgets::InsightsHuddlesWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "insights_huddles",
    group: "Insights",
    icon: "bi-chat-dots",
    selection_title: "Huddles Insights",
    selection_description: "Huddle insights.",
    label: "Huddles Insights",
    path: ->(c) { c.view.huddles_review_organization_path(c.organization) },
    description: "Huddle insights.",
    button_label: "Open Insights"
  }.freeze
end
