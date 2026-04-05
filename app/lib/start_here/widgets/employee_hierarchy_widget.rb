# frozen_string_literal: true

class StartHere::Widgets::EmployeeHierarchyWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "employee_hierarchy",
    group: "Directory",
    icon: "bi-diagram-3",
    selection_title: "Employee Hierarchy",
    selection_description: "Org hierarchy view.",
    label: "Employee Hierarchy",
    path: ->(c) {
      c.view.organization_employees_path(
        c.organization,
        spotlight: "manager_distribution",
        status: %w[unassigned_employee assigned_employee],
        view: "vertical_hierarchy"
      )
    },
    description: "Org hierarchy view.",
    button_label: "Employee Hierarchy"
  }.freeze
end
