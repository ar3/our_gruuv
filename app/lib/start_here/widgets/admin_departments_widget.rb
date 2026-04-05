# frozen_string_literal: true

class StartHere::Widgets::AdminDepartmentsWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "admin_departments",
    group: "Admin",
    icon: "bi-diagram-3",
    selection_title: "Departments",
    selection_description: "Departments.",
    label: "Departments",
    path: ->(c) { c.view.organization_departments_path(c.organization) },
    description: "Departments.",
    button_label: "Departments"
  }.freeze
end
