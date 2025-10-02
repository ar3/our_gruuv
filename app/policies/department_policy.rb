class DepartmentPolicy < OrganizationPolicy
  # Department inherits all behavior from OrganizationPolicy
  # This allows Pundit to find the correct policy for Department objects
end
