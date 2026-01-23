class MaapChangeExecutionService
  def initialize(maap_snapshot:, current_user:)
    @maap_snapshot = maap_snapshot
    @current_user = current_user
    @teammate = maap_snapshot&.employee_company_teammate
    @person = @teammate&.person
  end

  def execute!
    # Execute the MAAP changes based on the snapshot
    begin
      case @maap_snapshot.change_type
      when 'bulk_check_in_finalization'
        execute_bulk_check_in_finalization
      when 'individual_check_in_finalization'
        execute_individual_check_in_finalization
      when 'assignment_management'
        execute_assignment_management
      when 'position_tenure'
        execute_position_tenure_changes
      when 'milestone_management'
        execute_milestone_management
      when 'aspiration_management'
        execute_aspiration_management
      when 'exploration'
        execute_exploration_changes
      else
        false
      end
    rescue => e
      Rails.logger.error "Error executing MAAP changes: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false
    end
  end

  private

  attr_reader :maap_snapshot, :current_user, :person

  def execute_bulk_check_in_finalization
    # Execute bulk check-in finalization based on the snapshot
    if maap_snapshot.maap_data['assignments']
      execute_bulk_finalization_changes
    end
    true
  end

  def execute_bulk_finalization_changes
    maap_snapshot.maap_data['assignments'].each do |assignment_data|
      assignment = Assignment.find(assignment_data['id'])
      
      # Update check-in with finalization data
      if assignment_data['official_check_in']
        update_assignment_check_in(assignment, assignment_data)
      end
    end
  end

  def execute_individual_check_in_finalization
    # Implementation for individual check-in finalization
    true # Placeholder
  end

  def execute_assignment_management
    # Execute assignment changes
    if maap_snapshot.maap_data['assignments']
      execute_assignment_changes
    end
    true
  end

  def execute_assignment_changes
    maap_snapshot.maap_data['assignments'].each do |assignment_data|
      assignment = Assignment.find(assignment_data['id'])
      
      # Update tenure
      if assignment_data['tenure']
        update_assignment_tenure(assignment, assignment_data['tenure'])
      end
      
      # Update check-in
      if assignment_data['employee_check_in'] || assignment_data['manager_check_in'] || assignment_data['official_check_in']
        result = update_assignment_check_in(assignment, assignment_data)
        return false unless result # Return false if update failed
      end
    end
    true
  end

  def update_assignment_check_in(assignment, check_in_data)
    teammate = person.teammates.find_by(organization: assignment.company)
    return false unless teammate # Return false if teammate not found
    
    check_in = AssignmentCheckIn.where(teammate: teammate, assignment: assignment).open.first
    
    if check_in
      # Update existing check-in
      update_check_in_fields(check_in, check_in_data)
    else
      # Create new check-in
      check_in = AssignmentCheckIn.create!(
        teammate: teammate,
        assignment: assignment,
        check_in_started_on: Date.current
      )
      update_check_in_fields(check_in, check_in_data)
    end
    true
  end

  def execute_position_tenure_changes
    # Implementation for position tenure changes
    true # Placeholder
  end

  def execute_milestone_management
    # Implementation for milestone management
    true # Placeholder
  end

  def execute_aspiration_management
    # Implementation for aspiration management
    true # Placeholder
  end

  def execute_exploration_changes
    # Implementation for exploration changes
    true # Placeholder
  end

  def update_assignment_tenure(assignment, tenure_data)
    service = AssignmentTenureService.new(
      person: person,
      assignment: assignment,
      created_by: current_user
    )

    service.update_tenure(
      anticipated_energy_percentage: tenure_data['anticipated_energy_percentage'],
      started_at: tenure_data['started_at']
    )
  end

  def update_check_in_fields(check_in, check_in_data)
    # Only update fields that the current user is authorized to modify
    # This prevents concurrent updates from overwriting each other
    
    # Update employee check-in fields (only if current user is the employee)
    if check_in_data['employee_check_in'] && can_update_employee_check_in_fields?(check_in)
      update_employee_check_in_fields(check_in, check_in_data['employee_check_in'])
    end
    
    # Update manager check-in fields (only if current user is authorized manager)
    if check_in_data['manager_check_in'] && can_update_manager_check_in_fields?(check_in)
      update_manager_check_in_fields(check_in, check_in_data['manager_check_in'])
    end
    
    # Update official check-in fields (only if current user can finalize)
    if check_in_data['official_check_in'] && can_finalize_check_in?(check_in)
      update_official_check_in_fields(check_in, check_in_data['official_check_in'])
    end
    
    true # Return true to indicate success
  end

  def can_update_employee_check_in_fields?(check_in)
    # Employee can update their own check-in fields
    return false unless current_user.is_a?(CompanyTeammate)
    current_user.person == check_in.teammate.person || admin_bypass?
  end

  def can_update_manager_check_in_fields?(check_in)
    # Manager can update manager fields if they have management permissions
    return false unless current_user.is_a?(CompanyTeammate)
    return true if admin_bypass?
    
    # Employee cannot update their own manager fields
    return false if current_user.person == check_in.teammate.person
    
    # Check if current user can manage this teammate's assignments
    teammate_policy(check_in.teammate)&.manage_assignments? || false
  end

  def can_finalize_check_in?(check_in)
    # Only managers can finalize check-ins
    return false unless current_user.is_a?(CompanyTeammate)
    return true if admin_bypass?
    
    # Check if current user can manage this teammate's assignments
    teammate_policy(check_in.teammate)&.manage_assignments? || false
  end

  def update_employee_check_in_fields(check_in, employee_data)
    check_in.update!(
      actual_energy_percentage: employee_data['actual_energy_percentage'],
      employee_rating: employee_data['employee_rating'],
      employee_private_notes: employee_data['employee_private_notes'],
      employee_personal_alignment: employee_data['employee_personal_alignment']
    )
    
    if employee_data['employee_completed_at']
      check_in.complete_employee_side!
    elsif employee_data.key?('employee_completed_at') && employee_data['employee_completed_at'].nil?
      # Explicitly unchecking employee completion
      check_in.uncomplete_employee_side!
    end
  end

  def update_manager_check_in_fields(check_in, manager_data)
    check_in.update!(
      manager_rating: manager_data['manager_rating'],
      manager_private_notes: manager_data['manager_private_notes']
    )
    
    if manager_data['manager_completed_at']
      check_in.complete_manager_side!(completed_by: current_user)
    elsif manager_data.key?('manager_completed_at') && manager_data['manager_completed_at'].nil?
      # Explicitly unchecking manager completion
      check_in.uncomplete_manager_side!
    end
    # If manager_completed_at is present but not nil, preserve existing state (no action needed)
  end

  def update_official_check_in_fields(check_in, official_data)
    check_in.update!(
      official_rating: official_data['official_rating'],
      shared_notes: official_data['shared_notes']
    )
    
    if official_data['official_check_in_completed_at']
      check_in.finalize_check_in!(final_rating: official_data['official_rating'], finalized_by: current_user)
    end
  end

  def admin_bypass?
    return false unless current_user.is_a?(CompanyTeammate)
    current_user.person&.og_admin?
  end

  def policy(record)
    return nil unless current_user.is_a?(CompanyTeammate)
    pundit_user = OpenStruct.new(user: current_user, real_user: current_user)
    PersonPolicy.new(pundit_user, record)
  end

  def teammate_policy(teammate)
    return nil unless current_user.is_a?(CompanyTeammate)
    pundit_user = OpenStruct.new(user: current_user, real_user: current_user)
    CompanyTeammatePolicy.new(pundit_user, teammate)
  end
end
