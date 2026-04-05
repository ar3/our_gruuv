# frozen_string_literal: true

class StartHere::Widgets::MyHuddlesHuddlesWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "my_huddles_huddles",
    group: "Huddles",
    icon: "bi-person",
    selection_title: "My Huddles",
    selection_description: "Huddles you participate in.",
    label: "My Huddles",
    path: ->(c) { c.view.my_huddles_path },
    description: "Huddles you participate in.",
    button_label: "My Huddles"
  }.freeze
end
