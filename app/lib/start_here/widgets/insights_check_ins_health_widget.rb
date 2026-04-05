# frozen_string_literal: true

class StartHere::Widgets::InsightsCheckInsHealthWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "insights_check_ins_health",
    group: "Insights",
    icon: "bi-heart-pulse",
    selection_title: "Check-ins Health",
    selection_description: "Check-in health metrics.",
    label: "Check-ins Health",
    path: ->(c) { c.view.organization_check_ins_health_path(c.organization) },
    description: "Check-in health metrics.",
    button_label: "Check-ins Health"
  }.freeze
end
