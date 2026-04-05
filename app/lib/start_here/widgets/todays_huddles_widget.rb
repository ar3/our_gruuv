# frozen_string_literal: true

class StartHere::Widgets::TodaysHuddlesWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "todays_huddles",
    group: "Huddles",
    icon: "bi-calendar-event",
    selection_title: "Today's Huddles",
    selection_description: "Today's scheduled huddles.",
    label: "Today's Huddles",
    path: ->(c) { c.view.huddles_path },
    description: "Today's scheduled huddles.",
    button_label: "Today's Huddles"
  }.freeze
end
