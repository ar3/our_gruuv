# frozen_string_literal: true

class StartHere::Widgets::AbilitiesIndexWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "abilities_index",
    group: "Abilities and milestones",
    icon: "bi-award",
    selection_title: "Abilities",
    selection_description: "Browse abilities and milestones for the organization.",
    label: "Abilities",
    path: ->(c) { c.view.organization_abilities_path(c.organization) },
    description: "Browse abilities and milestones for the organization.",
    button_label: "Abilities"
  }.freeze
end
