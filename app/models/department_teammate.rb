class DepartmentTeammate < Teammate
  # Department-level teammates have more restricted permissions
  # They can manage department-specific resources but not employment
  
  # Department-specific validations
  validate :department_level_permissions
  
  # Department-specific methods
  def can_manage_department_resources?
    can_manage_maap?
  end
  
  private
  
  def department_level_permissions
    # Department teammates cannot manage employment
    if can_manage_employment?
      errors.add(:can_manage_employment, "Department teammates cannot manage employment")
    end
  end
end
