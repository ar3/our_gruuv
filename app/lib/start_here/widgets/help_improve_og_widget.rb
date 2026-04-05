# frozen_string_literal: true

class StartHere::Widgets::HelpImproveOgWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "help_improve_og",
    group: "Feedback",
    icon: "bi-lightbulb",
    selection_title: "Help Improve OG",
    selection_description: "Share product feedback and ideas.",
    label: "Help Improve OG",
    path: ->(c) {
      about_me_path = c.view.about_me_organization_company_teammate_path(c.organization, c.company_teammate)
      company_name = c.company&.name || c.organization&.name || "OurGruuv"
      c.view.interest_submissions_path(return_url: about_me_path, return_text: "back to #{company_name}'s Gruuv")
    },
    description: "Share product feedback and ideas.",
    button_label: "Help Improve OG"
  }.freeze
end
