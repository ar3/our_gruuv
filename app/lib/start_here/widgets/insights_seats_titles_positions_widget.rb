# frozen_string_literal: true

class StartHere::Widgets::InsightsSeatsTitlesPositionsWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "insights_seats_titles_positions",
    group: "Insights",
    icon: "bi-briefcase",
    selection_title: "Titles & Positions",
    selection_description: "Title and position insights.",
    label: "Titles & Positions",
    path: ->(c) { c.view.organization_insights_seats_titles_positions_path(c.organization) },
    description: "Title and position insights.",
    button_label: "Open Insights"
  }.freeze
end
