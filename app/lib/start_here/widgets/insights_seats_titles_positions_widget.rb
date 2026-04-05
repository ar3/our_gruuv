# frozen_string_literal: true

class StartHere::Widgets::InsightsSeatsTitlesPositionsWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "insights_seats_titles_positions",
    group: "Insights",
    icon: "bi-briefcase",
    selection_title: "Seats, Titles, Positions",
    selection_description: "Seat and title insights.",
    label: "Seats, Titles, Positions",
    path: ->(c) { c.view.organization_insights_seats_titles_positions_path(c.organization) },
    description: "Seat and title insights.",
    button_label: "Open Insights"
  }.freeze
end
