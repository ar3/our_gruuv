# frozen_string_literal: true

class StartHere::Widgets::AdminAspirationsWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "admin_aspirations",
    group: "Admin",
    icon: "bi-star",
    selection_title: "Aspirational Values",
    selection_description: "Aspirational values.",
    label: "Aspirational Values",
    path: ->(c) { c.view.organization_aspirations_path(c.organization) },
    description: "Aspirational values.",
    button_label: "Aspirational Values"
  }.freeze
end
