# frozen_string_literal: true

# Canonical "My Employees" directory link: managers view + Employee Health Overview spotlight.
module MyEmployeesLink
  VIEW = "managers_view"
  SPOTLIGHT = "employee_health_overview"

  module_function

  def path_params(manager_teammate_id:)
    {
      manager_teammate_id: manager_teammate_id,
      view: VIEW,
      spotlight: SPOTLIGHT
    }
  end
end
