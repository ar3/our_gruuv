# frozen_string_literal: true

class StartHere::Widgets::MyGoalsWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "my_goals",
    group: "About Me",
    icon: "bi-bullseye",
    selection_title: "My Goals",
    selection_description: "Goals you own or track.",
    label: "My Goals",
    path: ->(c) {
      if c.company_teammate
        c.view.organization_goals_path(c.organization, owner_id: "CompanyTeammate_#{c.company_teammate.id}")
      else
        c.view.organization_goals_path(c.organization)
      end
    },
    description: "Goals you own or track.",
    button_label: "Go to My Goals"
  }.freeze
end
