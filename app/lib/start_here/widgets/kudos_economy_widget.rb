# frozen_string_literal: true

class StartHere::Widgets::KudosEconomyWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "kudos_economy",
    group: "Kudos Center",
    icon: "bi-sliders",
    selection_title: "Kudos Economy",
    selection_description: "Configure kudos economy.",
    label: ->(c) { "#{c.view.company_label_plural('kudos_point', 'Kudos Point')} Economy" },
    path: ->(c) { c.view.organization_kudos_rewards_economy_path(c.organization) },
    description: "Configure kudos economy.",
    button_label: "Economy"
  }.freeze
end
