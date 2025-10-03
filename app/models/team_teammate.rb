class TeamTeammate < Teammate
  # Team-level teammates have the most restricted permissions
  # They can only manage team-specific resources
  
  # Team-specific validations
  validate :team_level_permissions
  
  # Team-specific methods
  def can_manage_team_resources?
    can_manage_maap?
  end
  
  private
  
  def team_level_permissions
    # Team teammates cannot manage employment
    if can_manage_employment?
      errors.add(:can_manage_employment, "Team teammates cannot manage employment")
    end
  end
end
