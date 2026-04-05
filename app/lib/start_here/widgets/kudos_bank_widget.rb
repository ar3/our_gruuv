# frozen_string_literal: true

class StartHere::Widgets::KudosBankWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "kudos_bank",
    group: "Kudos Center",
    icon: "bi-bank",
    selection_title: "Kudos Bank",
    selection_description: "Kudos bank awards.",
    label: ->(c) { "#{c.view.company_label_plural('kudos_point', 'Kudos Point')} Bank" },
    path: ->(c) { c.view.organization_kudos_rewards_bank_awards_path(c.organization) },
    description: "Kudos bank awards.",
    button_label: "Kudos Bank"
  }.freeze
end
