# frozen_string_literal: true

class StartHere::Widgets::DirectoryDepartmentsWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "directory_departments",
    group: "Directory",
    icon: "bi-diagram-3",
    selection_title: "Departments",
    selection_description: "Organization departments.",
    label: "Departments",
    path: ->(c) { c.view.organization_departments_path(c.organization) },
    description: "Organization departments.",
    button_label: "Departments"
  }.freeze
end
