# frozen_string_literal: true

class StartHere::Widgets::AboutPublicViewWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "about_public_view",
    group: "About Me",
    icon: "bi-globe",
    selection_title: "Public View",
    selection_description: "How your profile appears to others publicly.",
    label: "Public View",
    path: ->(c) { c.view.public_person_path(c.company_teammate.person) },
    description: "How your profile appears to others publicly.",
    button_label: "Public View"
  }.freeze
end
