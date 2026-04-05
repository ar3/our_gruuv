# frozen_string_literal: true

class StartHere::Widgets::CelebrateMilestonesWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "celebrate_milestones",
    group: "Abilities and milestones",
    icon: "bi-trophy",
    selection_title: "Celebrate Milestones",
    selection_description: "Celebrate team and individual milestones.",
    label: "Celebrate Milestones",
    path: ->(c) { c.view.celebrate_milestones_organization_path(c.organization) },
    description: "Celebrate team and individual milestones.",
    button_label: "Celebrate Milestones"
  }.freeze
end
