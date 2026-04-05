# frozen_string_literal: true

class StartHere::Widgets::KudosLeaderboardWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "kudos_leaderboard",
    group: "Kudos Center",
    icon: "bi-trophy",
    selection_title: "Kudos Leaderboard",
    selection_description: "Organization leaderboard.",
    label: ->(c) { "#{c.view.company_label_plural('kudos_point', 'Kudos Point')} Leader Board" },
    path: ->(c) { c.view.organization_kudos_rewards_leaderboard_path(c.organization) },
    description: "Organization leaderboard.",
    button_label: "Leader Board"
  }.freeze
end
