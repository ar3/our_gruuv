# frozen_string_literal: true

class StartHere::Widgets::MyEmployeesWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "my_employees",
    group: "Directory",
    icon: "bi-person-badge",
    selection_title: "My Employees",
    selection_description: "View and support the people who report to you.",
    label: "My Employees",
    path: ->(c) {
      c.view.organization_employees_path(
        c.organization,
        manager_teammate_id: c.company_teammate&.id,
        view: "managers_view",
        spotlight: "manager_lite"
      )
    },
    description: "View and support the people who report to you.",
    button_label: "My Employees"
  }.freeze
end
