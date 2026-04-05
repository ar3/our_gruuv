# frozen_string_literal: true

class StartHere::Widgets::AddNewOgoWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "add_new_ogo",
    group: "Observations (OGO)",
    icon: "bi-plus-circle",
    selection_title: "Add New OGO",
    selection_description: "Create a new observation.",
    label: "Add New OGO",
    path: ->(c) { c.view.select_type_organization_observations_path(c.organization) },
    description: "Create a new observation.",
    button_label: "Add New OGO"
  }.freeze
end
