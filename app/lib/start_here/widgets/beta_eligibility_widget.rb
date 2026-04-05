# frozen_string_literal: true

class StartHere::Widgets::BetaEligibilityWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "beta_eligibility",
    group: "Beta",
    icon: "bi-check2-circle",
    selection_title: "Eligibility Requirements",
    selection_description: "Eligibility requirements.",
    label: "Eligibility Requirements",
    path: ->(c) { c.view.organization_eligibility_requirements_path(c.organization) },
    description: "Eligibility requirements.",
    button_label: "Eligibility Requirements"
  }.freeze
end
