# frozen_string_literal: true

class StartHere::Widgets::KudosRewardsCatalogWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "kudos_rewards_catalog",
    group: "Kudos Center",
    icon: "bi-gift",
    selection_title: "Rewards Catalog",
    selection_description: "Browse redeemable rewards.",
    label: "Rewards Catalog",
    path: ->(c) { c.view.organization_kudos_rewards_rewards_path(c.organization) },
    description: "Browse redeemable rewards.",
    button_label: "Rewards Catalog"
  }.freeze
end
