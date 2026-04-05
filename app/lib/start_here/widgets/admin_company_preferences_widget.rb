# frozen_string_literal: true

class StartHere::Widgets::AdminCompanyPreferencesWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "admin_company_preferences",
    group: "Admin",
    icon: "bi-sliders",
    selection_title: "Admin Company Preferences",
    selection_description: "Company preferences.",
    label: ->(c) { "#{c.company.name} Preferences" },
    path: ->(c) { c.view.edit_organization_company_preference_path(c.organization) },
    description: "Company preferences.",
    button_label: "Preferences"
  }.freeze
end
