# frozen_string_literal: true

class StartHere::Widgets::KudosMyBalanceWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "kudos_my_balance",
    group: "Kudos Center",
    icon: "bi-wallet2",
    selection_title: "My Balance",
    selection_description: "Your kudos point balance.",
    label: "My Balance",
    path: ->(c) { c.view.kudos_points_organization_company_teammate_path(c.organization, c.company_teammate) },
    description: "Your kudos point balance.",
    button_label: "My Balance"
  }.freeze
end
