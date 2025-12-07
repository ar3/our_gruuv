class UserPreferencePolicy < ApplicationPolicy
  def update?
    return true if admin_bypass?
    return false unless viewing_teammate && record
    
    # Users can only update their own preferences
    viewing_teammate.person == record.person
  end
  
  def update_layout?
    update?
  end
  
  def update_vertical_nav?
    update?
  end
end

