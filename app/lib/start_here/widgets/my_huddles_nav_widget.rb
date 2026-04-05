# frozen_string_literal: true

class StartHere::Widgets::MyHuddlesNavWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "my_huddles_nav",
    group: "About Me",
    icon: "bi-person",
    selection_title: "My Huddles",
    selection_description: "Huddles you participate in.",
    label: "My Huddles",
    path: ->(c) { c.view.my_huddles_path },
    description: "Huddles you participate in.",
    button_label: "Open My Huddles"
  }.freeze
end
