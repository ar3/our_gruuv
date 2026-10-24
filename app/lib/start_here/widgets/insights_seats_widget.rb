# frozen_string_literal: true

class StartHere::Widgets::InsightsSeatsWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "insights_seats",
    group: "Insights",
    icon: "bi-person-workspace",
    selection_title: "Seats",
    selection_description: "Seat lifecycle and considered / open / filled insights.",
    label: "Seats",
    path: ->(c) { c.view.organization_insights_seats_path(c.organization) },
    description: "Seat lifecycle and considered / open / filled insights.",
    button_label: "Open Insights"
  }.freeze
end
