class OrganizationPolicy < ApplicationPolicy
  def show?
    true # Anyone can view organization details
  end

  def manage_employment?
    # Check if the current person has employment management access for this organization
    return false unless user
    
    user.can_manage_employment?(record)
  end
  
  def create_employment?
    # Check if the current person has employment creation access for this organization
    return false unless user
    
    user.can_create_employment?(record)
  end

  def manage_maap?
    # Check if the current person has MAAP management access for this organization
    return false unless user
    
    user.can_manage_maap?(record)
  end
end
