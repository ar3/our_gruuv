# frozen_string_literal: true

class StartHere::Widgets::AboutKudosPointsModeWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "about_kudos_points_mode",
    group: "About Me",
    icon: "bi-star",
    selection_title: "About Kudos Points Mode",
    selection_description: "Your kudos points balance and activity.",
    label: ->(c) { "#{c.view.company_label_plural('kudos_point', 'Kudos Point')} Mode" },
    path: ->(c) { c.view.kudos_points_organization_company_teammate_path(c.organization, c.company_teammate) },
    description: ->(c) { "Your #{c.view.company_label_plural('kudos_point', 'kudos points')} balance and activity." },
    button_label: ->(c) { "#{c.view.company_label_plural('kudos_point', 'Kudos Point')} Mode" }
  }.freeze
end
