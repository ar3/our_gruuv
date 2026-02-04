module OrganizationsHelper
  def get_connection_reasons(person, organization)
    reasons = []
    
    # Check employment
    if person.active_employment_tenure_in?(organization)
      reasons << "Position"
    end
    
    # Check huddle participation
    if person.huddle_participants.joins(huddle: :team).where(teams: { company_id: organization.id }).exists?
      reasons << "Huddle"
    end
    
    # Check access permissions
    if person.teammates.where(organization: organization).exists?
      reasons << "Access"
    end
    
    # Check milestone achievements (coming soon)
    # if person.teammate_milestones.joins(:ability).where(abilities: { company_id: organization.id }).exists?
    #   reasons << "Milestone"
    # end
    
    # Check assignment participation (coming soon)
    # if person.assignment_tenures.joins(:assignment).where(assignments: { organization: organization }).exists?
    #   reasons << "Accountability"
    # end
    
    reasons
  end
  
  # Get detailed teammate debugging information for an organization
  def get_teammate_debug_info(person, organization)
    root_company = organization.root_company || organization
    teammate = person.teammates.find_by(organization: root_company)
    
    {
      teammate_id: teammate&.id,
      teammate_type: teammate&.type,
      teammate_exists: teammate.present?,
      root_company_id: root_company.id,
      root_company_name: root_company.name,
      first_employed_at: teammate&.first_employed_at,
      last_terminated_at: teammate&.last_terminated_at,
      is_terminated: teammate&.last_terminated_at.present?,
      is_active: teammate&.last_terminated_at.nil?,
      will_create_new: teammate.nil?,
      created_at: teammate&.created_at,
      is_company_teammate: teammate.is_a?(CompanyTeammate)
    }
  end
  
  # Determine if organization switch will likely succeed
  def get_switch_readiness(person, organization)
    debug_info = get_teammate_debug_info(person, organization)
    
    if debug_info[:is_terminated]
      {
        status: :error,
        badge_class: 'bg-danger',
        icon: 'bi-x-circle-fill',
        label: 'Terminated',
        reason: 'Teammate record is terminated',
        will_succeed: false
      }
    elsif debug_info[:will_create_new]
      {
        status: :warning,
        badge_class: 'bg-warning text-dark',
        icon: 'bi-plus-circle-fill',
        label: 'Will Create',
        reason: 'New teammate record will be created',
        will_succeed: true
      }
    elsif debug_info[:is_active] && debug_info[:is_company_teammate]
      {
        status: :success,
        badge_class: 'bg-success',
        icon: 'bi-check-circle-fill',
        label: 'Ready',
        reason: 'Active CompanyTeammate exists',
        will_succeed: true
      }
    elsif debug_info[:is_active]
      {
        status: :info,
        badge_class: 'bg-info',
        icon: 'bi-arrow-repeat',
        label: 'Will Convert',
        reason: 'Teammate will be converted to CompanyTeammate',
        will_succeed: true
      }
    else
      {
        status: :unknown,
        badge_class: 'bg-secondary',
        icon: 'bi-question-circle-fill',
        label: 'Unknown',
        reason: 'Unexpected state',
        will_succeed: false
      }
    end
  end
  
  # Get session health information for debugging
  def session_debug_info
    {
      has_session_id: session.id.present?,
      session_teammate_id: session[:current_company_teammate_id],
      current_teammate_valid: current_company_teammate.present?,
      impersonating: impersonating?,
      secure_connection: request.ssl?,
      user_agent: request.user_agent,
      session_keys: session.keys.grep(/teammate|person|organization/)
    }
  end
  
  # Format teammate status for display
  def teammate_status_badge(debug_info)
    if debug_info[:is_terminated]
      content_tag(:span, class: 'badge bg-danger') do
        content_tag(:i, '', class: 'bi bi-x-circle me-1') + 'Terminated'
      end
    elsif debug_info[:will_create_new]
      content_tag(:span, class: 'badge bg-secondary') do
        content_tag(:i, '', class: 'bi bi-dash-circle me-1') + 'None'
      end
    elsif debug_info[:is_active]
      content_tag(:span, class: 'badge bg-success') do
        content_tag(:i, '', class: 'bi bi-check-circle me-1') + 'Active'
      end
    else
      content_tag(:span, class: 'badge bg-warning text-dark') do
        content_tag(:i, '', class: 'bi bi-exclamation-circle me-1') + 'Unknown'
      end
    end
  end
  
  # Format switch readiness badge
  def switch_readiness_badge(readiness)
    content_tag(:span, class: "badge #{readiness[:badge_class]}") do
      content_tag(:i, '', class: "#{readiness[:icon]} me-1") + readiness[:label]
    end
  end

  # Get full name for assignment including company and department hierarchy
  def assignment_full_name(assignment)
    path = []
    
    # Start with company
    company = assignment.company
    path << company.name if company
    
    # Add department hierarchy if present (excluding the company which is already included)
    if assignment.department
      current = assignment.department
      dept_path = []
      while current
        # Stop before including the company (which is already in the path)
        break if current.company?
        dept_path.unshift(current.name)
        current = current.respond_to?(:parent_department) ? current.parent_department : current.parent
      end
      path.concat(dept_path)
    end
    
    # Add assignment title
    path << assignment.title
    
    path.join(' > ')
  end

  # Get department hierarchy display string
  def department_hierarchy_display(department)
    return '' unless department
    return department.display_name if department.is_a?(Department)
    
    # Fallback for Organization (legacy support)
    path = []
    current = department
    while current
      path.unshift(current.name)
      current = current.respond_to?(:parent_department) ? current.parent_department : current.parent
    end
    path.join(' > ')
  end

  # Determine table row class based on assignment tenure status
  # latest_tenure: nil = no tenure, ended_at present = ended (info), ended_at nil = active (success)
  def assignment_row_class(latest_tenure)
    return '' unless latest_tenure
    
    if latest_tenure.ended_at.nil?
      'table-success' # Active tenure
    else
      'table-info' # Ended tenure
    end
  end

  # Get last active tenure information
  def last_active_tenure_info(assignment, teammate)
    last_tenure = teammate.assignment_tenures
                          .where(assignment: assignment)
                          .where.not(ended_at: nil)
                          .order(started_at: :desc)
                          .first
    
    return nil unless last_tenure
    
    {
      started_at: last_tenure.started_at,
      ended_at: last_tenure.ended_at,
      anticipated_energy_percentage: last_tenure.anticipated_energy_percentage
    }
  end

  # Check if assignment has any check-ins or tenures
  def has_check_in_or_tenure_history?(assignment, teammate)
    teammate.assignment_tenures.where(assignment: assignment).exists? ||
      AssignmentCheckIn.where(company_teammate: teammate, assignment: assignment).exists?
  end
end
