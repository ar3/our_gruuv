module OrganizationsHelper
  def get_connection_reasons(person, organization)
    reasons = []
    
    # Check employment
    if person.active_employment_tenure_in?(organization)
      reasons << "Position"
    end
    
    # Check huddle participation
    if person.huddles.joins(:huddle_playbook).where(huddle_playbooks: { organization: organization }).exists?
      reasons << "Huddle"
    end
    
    # Check access permissions
    if person.teammates.where(organization: organization).exists?
      reasons << "Access"
    end
    
    # Check milestone achievements (coming soon)
    # if person.person_milestones.joins(:ability).where(abilities: { organization: organization }).exists?
    #   reasons << "Milestone"
    # end
    
    # Check assignment participation (coming soon)
    # if person.assignment_tenures.joins(:assignment).where(assignments: { organization: organization }).exists?
    #   reasons << "Accountability"
    # end
    
    reasons
  end
end
