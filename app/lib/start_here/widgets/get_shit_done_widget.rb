# frozen_string_literal: true

class StartHere::Widgets::GetShitDoneWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "get_shit_done",
    group: "Get things done",
    icon: "bi-clipboard-check",
    selection_title: "Get Shit Done",
    selection_description: "See what needs your attention across your work.",
    label: ->(c) {
      gsd = c.view.company_label_for("get_shit_done", "Get Shit Done")
      "#{c.casual_name}'s #{gsd} list"
    },
    path: ->(c) { c.view.organization_get_shit_done_path(c.organization) },
    description: :start_here_dynamic_gsd,

    button_label: ->(c) { "Open #{c.view.company_label_for('get_shit_done', 'Get Shit Done')}" }
  }.freeze
end
