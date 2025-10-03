class CompanyTeammate < Teammate
  # Company-level teammates can have any combination of permissions
  # They have the highest level of access within the organization
  
  # Company-specific validations
  validate :company_level_permissions
  
  # Company-specific methods
  def can_manage_anything?
    can_manage_employment? && can_manage_maap?
  end
  
  def has_full_access?
    can_manage_employment? && can_manage_maap? && can_create_employment?
  end
  
  private
  
  def company_level_permissions
    # Company teammates can have any combination of permissions
    # No additional restrictions at this level
  end
end
