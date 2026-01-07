class MaapChangeDetectionService
  def initialize(person:, maap_snapshot:, current_user: nil, previous_snapshot: nil)
    @person = person
    @maap_snapshot = maap_snapshot
    @current_user = current_user
    @previous_snapshot = previous_snapshot
  end

  # Returns a hash with counts of changes by category
  def change_counts
    {
      employment: employment_changes_count,
      assignments: assignment_changes_count,
      milestones: milestone_changes_count,
      aspirations: aspiration_changes_count
    }
  end

  # Returns detailed change information for debugging
  def detailed_changes
    {
      employment: employment_changes_detail,
      assignments: assignment_changes_detail,
      milestones: milestone_changes_detail,
      aspirations: aspiration_changes_detail
    }
  end

  def assignment_has_changes?(assignment)
    return false unless maap_snapshot&.maap_data&.dig('assignments')
    
    proposed_data = maap_snapshot.maap_data['assignments'].find { |a| a['assignment_id'] == assignment.id }
    return false unless proposed_data
    
    previous_assignments = previous_snapshot&.maap_data&.dig('assignments') || []
    previous_data = previous_assignments.find { |a| a['assignment_id'] == assignment.id }
    
    # Check assignment changes
    if previous_data
      previous_data['anticipated_energy_percentage'] != proposed_data['anticipated_energy_percentage'] ||
      previous_data['official_rating'] != proposed_data['official_rating']
    else
      # No previous assignment - check if we're creating a new one
      proposed_data['anticipated_energy_percentage'].to_i > 0 || proposed_data['official_rating'].present?
    end
  end

  private

  attr_reader :person, :maap_snapshot, :previous_snapshot

  def employment_changes_count
    employment_has_changes? ? 1 : 0
  end

  def assignment_changes_count
    return 0 unless maap_snapshot&.maap_data&.dig('assignments')
    
    assignment_changes_detail[:has_changes] ? assignment_changes_detail[:details].count : 0
  end

  def milestone_changes_count
    return 0 unless maap_snapshot&.maap_data&.dig('abilities')
    
    milestone_changes_detail[:has_changes] ? milestone_changes_detail[:details].count : 0
  end

  def aspiration_changes_count
    return 0 unless maap_snapshot&.maap_data&.dig('aspirations')
    
    aspiration_changes_detail[:has_changes] ? aspiration_changes_detail[:details].count : 0
  end

  def employment_changes_detail
    return { has_changes: false, details: [] } unless maap_snapshot&.maap_data&.dig('position')
    
    previous_rated = previous_snapshot&.maap_data&.dig('position', 'rated_position') || {}
    proposed_rated = maap_snapshot.maap_data.dig('position', 'rated_position') || {}
    
    changes = []
    
    # If previous is empty and proposed has data, show as new rating
    if previous_rated.empty? && !proposed_rated.empty?
      changes << { field: 'new_rated_position', current: 'none', proposed: 'new rating' }
    # If previous has data and proposed is empty, show as rating removed (unlikely)
    elsif !previous_rated.empty? && proposed_rated.empty?
      changes << { field: 'rated_position_removed', current: 'had rating', proposed: 'none' }
    # Compare all fields within rated_position
    elsif !previous_rated.empty? && !proposed_rated.empty?
      if previous_rated['seat_id'].to_s != proposed_rated['seat_id'].to_s
        changes << { field: 'rated_seat', current: previous_rated['seat_id'], proposed: proposed_rated['seat_id'] }
      end
      if previous_rated['manager_teammate_id'].to_s != proposed_rated['manager_teammate_id'].to_s
        changes << { field: 'rated_manager', current: previous_rated['manager_teammate_id'], proposed: proposed_rated['manager_teammate_id'] }
      end
      if previous_rated['position_id'].to_s != proposed_rated['position_id'].to_s
        changes << { field: 'rated_position', current: previous_rated['position_id'], proposed: proposed_rated['position_id'] }
      end
      if previous_rated['employment_type'] != proposed_rated['employment_type']
        changes << { field: 'rated_employment_type', current: previous_rated['employment_type'], proposed: proposed_rated['employment_type'] }
      end
      if previous_rated['official_position_rating'] != proposed_rated['official_position_rating']
        changes << { field: 'official_position_rating', current: previous_rated['official_position_rating'], proposed: proposed_rated['official_position_rating'] }
      end
      if previous_rated['started_at'] != proposed_rated['started_at']
        changes << { field: 'rated_started_at', current: previous_rated['started_at'], proposed: proposed_rated['started_at'] }
      end
      if previous_rated['ended_at'] != proposed_rated['ended_at']
        changes << { field: 'rated_ended_at', current: previous_rated['ended_at'], proposed: proposed_rated['ended_at'] }
      end
    end
    
    { has_changes: changes.any?, details: changes }
  end

  def assignment_changes_detail
    return { has_changes: false, details: [] } unless maap_snapshot&.maap_data&.dig('assignments')
    
    previous_assignments = previous_snapshot&.maap_data&.dig('assignments') || []
    proposed_assignments = maap_snapshot.maap_data['assignments'] || []
    
    # Get all assignment IDs from both snapshots
    all_assignment_ids = (previous_assignments.map { |a| a['assignment_id'] } + proposed_assignments.map { |a| a['assignment_id'] }).uniq.compact
    assignments = Assignment.where(id: all_assignment_ids).index_by(&:id)
    
    changes = []
    
    proposed_assignments.each do |proposed_data|
      assignment_id = proposed_data['assignment_id']
      assignment = assignments[assignment_id]
      next unless assignment
      
      previous_data = previous_assignments.find { |a| a['assignment_id'] == assignment_id }
      assignment_changes = []
      
      # Compare top-level anticipated_energy_percentage (from active tenure)
      if previous_data
        if previous_data['anticipated_energy_percentage'] != proposed_data['anticipated_energy_percentage']
          assignment_changes << {
            field: 'anticipated_energy_percentage',
            current: previous_data['anticipated_energy_percentage'],
            proposed: proposed_data['anticipated_energy_percentage']
          }
        end
        
        # Compare rated_assignment objects
        previous_rated = previous_data['rated_assignment'] || {}
        proposed_rated = proposed_data['rated_assignment'] || {}
        
        # If previous is empty and proposed has data, show as new rating
        if previous_rated.empty? && !proposed_rated.empty?
          assignment_changes << {
            field: 'new_rated_assignment',
            current: 'none',
            proposed: 'new rating'
          }
        # If previous has data and proposed is empty, show as rating removed (unlikely)
        elsif !previous_rated.empty? && proposed_rated.empty?
          assignment_changes << {
            field: 'rated_assignment_removed',
            current: 'had rating',
            proposed: 'none'
          }
        # Compare all fields within rated_assignment
        elsif !previous_rated.empty? && !proposed_rated.empty?
          if previous_rated['official_rating'] != proposed_rated['official_rating']
            assignment_changes << {
              field: 'official_rating',
              current: previous_rated['official_rating'],
              proposed: proposed_rated['official_rating']
            }
          end
          if previous_rated['anticipated_energy_percentage'] != proposed_rated['anticipated_energy_percentage']
            assignment_changes << {
              field: 'rated_anticipated_energy_percentage',
              current: previous_rated['anticipated_energy_percentage'],
              proposed: proposed_rated['anticipated_energy_percentage']
            }
          end
          if previous_rated['started_at'] != proposed_rated['started_at']
            assignment_changes << {
              field: 'rated_started_at',
              current: previous_rated['started_at'],
              proposed: proposed_rated['started_at']
            }
          end
          if previous_rated['ended_at'] != proposed_rated['ended_at']
            assignment_changes << {
              field: 'rated_ended_at',
              current: previous_rated['ended_at'],
              proposed: proposed_rated['ended_at']
            }
          end
        end
      else
        # No previous assignment - check if we're creating a new one
        if proposed_data['anticipated_energy_percentage'].to_i > 0
          assignment_changes << {
            field: 'new_assignment',
            current: 'none',
            proposed: "#{proposed_data['anticipated_energy_percentage']}% energy"
          }
        end
        # Also check if there's a rated_assignment (new rating)
        proposed_rated = proposed_data['rated_assignment'] || {}
        if !proposed_rated.empty? && proposed_rated['official_rating'].present?
          assignment_changes << {
            field: 'new_rated_assignment',
            current: 'none',
            proposed: 'new rating'
          }
        end
      end
      
      if assignment_changes.any?
        changes << {
          assignment: assignment.title,
          assignment_id: assignment.id,
          changes: assignment_changes
        }
      end
    end
    
    { has_changes: changes.any?, details: changes }
  end

  def check_in_changes_detail(assignment, proposed_data, previous_data = nil)
    previous_employee_check_in = previous_data&.dig('employee_check_in')
    previous_manager_check_in = previous_data&.dig('manager_check_in')
    previous_official_check_in = previous_data&.dig('official_check_in')
    
    changes = []
    
    # Employee check-in changes
    if proposed_data['employee_check_in']
      employee_data = proposed_data['employee_check_in']
      
      if previous_employee_check_in
        if (previous_employee_check_in['actual_energy_percentage'] || 0) != (employee_data['actual_energy_percentage'] || 0)
          changes << { field: 'employee_actual_energy', current: previous_employee_check_in['actual_energy_percentage'], proposed: employee_data['actual_energy_percentage'] }
        end
        if previous_employee_check_in['employee_rating'] != employee_data['employee_rating']
          changes << { field: 'employee_rating', current: previous_employee_check_in['employee_rating'], proposed: employee_data['employee_rating'] }
        end
        if previous_employee_check_in['employee_personal_alignment'] != employee_data['employee_personal_alignment']
          changes << { field: 'employee_personal_alignment', current: previous_employee_check_in['employee_personal_alignment'], proposed: employee_data['employee_personal_alignment'] }
        end
        if previous_employee_check_in['employee_private_notes'] != employee_data['employee_private_notes']
          changes << { field: 'employee_private_notes', current: previous_employee_check_in['employee_private_notes'], proposed: employee_data['employee_private_notes'] }
        end
        if previous_employee_check_in['employee_completed_at'].present? != employee_data['employee_completed_at'].present?
          changes << { field: 'employee_completion', current: previous_employee_check_in['employee_completed_at'].present?, proposed: employee_data['employee_completed_at'].present? }
        end
      else
        # New check-in
        if employee_data.values.any? { |v| v.present? }
          changes << { field: 'new_employee_check_in', current: 'none', proposed: 'new check-in' }
        end
      end
    end
    
    # Manager check-in changes
    if proposed_data['manager_check_in']
      manager_data = proposed_data['manager_check_in']
      
      if previous_manager_check_in
        if previous_manager_check_in['manager_rating'] != manager_data['manager_rating']
          changes << { field: 'manager_rating', current: previous_manager_check_in['manager_rating'], proposed: manager_data['manager_rating'] }
        end
        if previous_manager_check_in['manager_private_notes'] != manager_data['manager_private_notes']
          changes << { field: 'manager_private_notes', current: previous_manager_check_in['manager_private_notes'], proposed: manager_data['manager_private_notes'] }
        end
        if previous_manager_check_in['manager_completed_at'].present? != manager_data['manager_completed_at'].present?
          changes << { field: 'manager_completion', current: previous_manager_check_in['manager_completed_at'].present?, proposed: manager_data['manager_completed_at'].present? }
        end
      else
        # New check-in
        if manager_data.values.any? { |v| v.present? }
          changes << { field: 'new_manager_check_in', current: 'none', proposed: 'new check-in' }
        end
      end
    end
    
    # Official check-in changes
    if proposed_data['official_check_in']
      official_data = proposed_data['official_check_in']
      
      if previous_official_check_in
        if previous_official_check_in['official_rating'] != official_data['official_rating']
          changes << { field: 'official_rating', current: previous_official_check_in['official_rating'], proposed: official_data['official_rating'] }
        end
        if previous_official_check_in['shared_notes'] != official_data['shared_notes']
          changes << { field: 'shared_notes', current: previous_official_check_in['shared_notes'], proposed: official_data['shared_notes'] }
        end
        if previous_official_check_in['official_check_in_completed_at'].present? != official_data['official_check_in_completed_at'].present?
          changes << { field: 'official_completion', current: previous_official_check_in['official_check_in_completed_at'].present?, proposed: official_data['official_check_in_completed_at'].present? }
        end
        if previous_official_check_in['finalized_by_id'].to_s != official_data['finalized_by_id'].to_s
          changes << { field: 'finalized_by', current: previous_official_check_in['finalized_by_id'], proposed: official_data['finalized_by_id'] }
        end
      else
        # New check-in
        if official_data.values.any? { |v| v.present? }
          changes << { field: 'new_official_check_in', current: 'none', proposed: 'new check-in' }
        end
      end
    end
    
    changes
  end

  def milestone_changes_detail
    return { has_changes: false, details: [] } unless maap_snapshot&.maap_data&.dig('abilities')
    
    previous_abilities = previous_snapshot&.maap_data&.dig('abilities') || []
    proposed_abilities = maap_snapshot.maap_data['abilities'] || []
    
    # Get all ability IDs from both snapshots
    all_ability_ids = (previous_abilities.map { |m| m['ability_id'] } + proposed_abilities.map { |m| m['ability_id'] }).uniq.compact
    abilities = Ability.where(id: all_ability_ids).index_by(&:id)
    
    changes = []
    
    proposed_abilities.each do |proposed_data|
      ability_id = proposed_data['ability_id']
      ability = abilities[ability_id]
      next unless ability
      
      previous_data = previous_abilities.find { |m| m['ability_id'] == ability_id }
      milestone_changes = []
      
      if previous_data
        if previous_data['milestone_level'] != proposed_data['milestone_level']
          milestone_changes << { field: 'milestone_level', current: previous_data['milestone_level'], proposed: proposed_data['milestone_level'] }
        end
        if previous_data['certifying_teammate_id'].to_s != proposed_data['certifying_teammate_id'].to_s
          milestone_changes << { field: 'certifying_teammate', current: previous_data['certifying_teammate_id'], proposed: proposed_data['certifying_teammate_id'] }
        end
        if previous_data['attained_at'].to_s != proposed_data['attained_at'].to_s
          milestone_changes << { field: 'attained_at', current: previous_data['attained_at'], proposed: proposed_data['attained_at'] }
        end
      else
        # New milestone - all fields are new
        milestone_changes << { field: 'milestone_level', current: 'none', proposed: proposed_data['milestone_level'] }
        if proposed_data['certifying_teammate_id'].present?
          milestone_changes << { field: 'certifying_teammate', current: 'none', proposed: proposed_data['certifying_teammate_id'] }
        end
        if proposed_data['attained_at'].present?
          milestone_changes << { field: 'attained_at', current: 'none', proposed: proposed_data['attained_at'] }
        end
      end
      
      if milestone_changes.any?
        changes << {
          ability: ability.name,
          ability_id: ability_id,
          changes: milestone_changes
        }
      end
    end
    
    { has_changes: changes.any?, details: changes }
  end

  def aspiration_changes_detail
    return { has_changes: false, details: [] } unless maap_snapshot&.maap_data&.dig('aspirations')
    
    previous_aspirations = previous_snapshot&.maap_data&.dig('aspirations') || []
    proposed_aspirations = maap_snapshot.maap_data['aspirations'] || []
    
    # Get all aspiration IDs from both snapshots
    all_aspiration_ids = (previous_aspirations.map { |a| a['aspiration_id'] } + proposed_aspirations.map { |a| a['aspiration_id'] }).uniq.compact
    aspirations = Aspiration.where(id: all_aspiration_ids).index_by(&:id)
    
    changes = []
    
    proposed_aspirations.each do |proposed_data|
      aspiration_id = proposed_data['aspiration_id']
      aspiration = aspirations[aspiration_id]
      next unless aspiration
      
      previous_data = previous_aspirations.find { |a| a['aspiration_id'] == aspiration_id }
      aspiration_changes = []
      
      if previous_data
        if previous_data['official_rating'] != proposed_data['official_rating']
          aspiration_changes << {
            field: 'official_rating',
            current: previous_data['official_rating'],
            proposed: proposed_data['official_rating']
          }
        end
      else
        # New aspiration rating
        if proposed_data['official_rating'].present?
          aspiration_changes << {
            field: 'new_aspiration_rating',
            current: 'none',
            proposed: proposed_data['official_rating']
          }
        end
      end
      
      if aspiration_changes.any?
        changes << {
          aspiration: aspiration.name || "Aspiration #{aspiration_id}",
          aspiration_id: aspiration_id,
          changes: aspiration_changes
        }
      end
    end
    
    { has_changes: changes.any?, details: changes }
  end

  def load_assignment_data
    # Get all assignments that have tenures OR are in the snapshot
    teammate = person.teammates.find_by(organization: maap_snapshot.company)
    assignment_ids_from_tenures = teammate&.assignment_tenures&.distinct&.pluck(:assignment_id) || []
    assignment_ids_from_snapshot = maap_snapshot.maap_data['assignments']&.map { |a| a['assignment_id'] } || []
    all_assignment_ids = (assignment_ids_from_tenures + assignment_ids_from_snapshot).uniq
    
    assignments = Assignment.where(id: all_assignment_ids).includes(:assignment_tenures)
    
    assignments.map do |assignment|
      {
        assignment: assignment,
        active_tenure: teammate&.assignment_tenures&.where(assignment: assignment)&.active&.first
      }
    end
  end

  def employment_has_changes?
    return false unless maap_snapshot&.maap_data&.dig('position')
    
    previous_rated = previous_snapshot&.maap_data&.dig('position', 'rated_position') || {}
    proposed_rated = maap_snapshot.maap_data.dig('position', 'rated_position') || {}
    
    # If previous is empty and proposed has data, that's a change
    return true if previous_rated.empty? && !proposed_rated.empty?
    # If previous has data and proposed is empty, that's a change (unlikely but handle)
    return true if !previous_rated.empty? && proposed_rated.empty?
    # If both are empty, no changes
    return false if previous_rated.empty? && proposed_rated.empty?
    
    # Compare all fields within rated_position
    previous_rated['seat_id'].to_s != proposed_rated['seat_id'].to_s ||
    previous_rated['manager_teammate_id'].to_s != proposed_rated['manager_teammate_id'].to_s ||
    previous_rated['position_id'].to_s != proposed_rated['position_id'].to_s ||
    previous_rated['employment_type'] != proposed_rated['employment_type'] ||
    previous_rated['official_position_rating'] != proposed_rated['official_position_rating'] ||
    previous_rated['started_at'] != proposed_rated['started_at'] ||
    previous_rated['ended_at'] != proposed_rated['ended_at']
  end


  def check_in_has_changes?(assignment, proposed_data, previous_data = nil)
    previous_employee_check_in = previous_data&.dig('employee_check_in')
    previous_manager_check_in = previous_data&.dig('manager_check_in')
    previous_official_check_in = previous_data&.dig('official_check_in')
    
    # Check employee check-in changes
    if proposed_data['employee_check_in']
      employee_data = proposed_data['employee_check_in']
      if previous_employee_check_in
        employee_changed = (previous_employee_check_in['actual_energy_percentage'] || 0) != (employee_data['actual_energy_percentage'] || 0) ||
          previous_employee_check_in['employee_rating'] != employee_data['employee_rating'] ||
          previous_employee_check_in['employee_personal_alignment'] != employee_data['employee_personal_alignment'] ||
          previous_employee_check_in['employee_private_notes'] != employee_data['employee_private_notes'] ||
          previous_employee_check_in['employee_completed_at'].present? != employee_data['employee_completed_at'].present?
        return true if employee_changed
      elsif employee_data.values.any? { |v| v.present? }
        return true
      end
    end
    
    # Check manager check-in changes
    if proposed_data['manager_check_in']
      manager_data = proposed_data['manager_check_in']
      if previous_manager_check_in
        manager_changed = previous_manager_check_in['manager_rating'] != manager_data['manager_rating'] ||
          previous_manager_check_in['manager_private_notes'] != manager_data['manager_private_notes'] ||
          previous_manager_check_in['manager_completed_at'].present? != manager_data['manager_completed_at'].present?
        return true if manager_changed
      elsif manager_data.values.any? { |v| v.present? }
        return true
      end
    end
    
    # Check official check-in changes
    if proposed_data['official_check_in']
      official_data = proposed_data['official_check_in']
      if previous_official_check_in
        official_changed = previous_official_check_in['official_rating'] != official_data['official_rating'] ||
          previous_official_check_in['shared_notes'] != official_data['shared_notes'] ||
          previous_official_check_in['official_check_in_completed_at'].present? != official_data['official_check_in_completed_at'].present? ||
          previous_official_check_in['finalized_by_id'].to_s != official_data['finalized_by_id'].to_s
        return true if official_changed
      elsif official_data.values.any? { |v| v.present? }
        return true
      end
    end
    
    false
  end

  private

  attr_reader :person, :maap_snapshot, :current_user, :previous_snapshot

  def can_update_employee_check_in_fields?(check_in)
    # Employee can update their own check-in fields
    return false unless current_user
    
    # If check_in is nil, we're creating a new check-in
    # Employee can create check-ins for themselves
    return true if check_in.nil? && current_user.is_a?(CompanyTeammate) && current_user.person == person
    
    # If check_in exists, check if employee can update their own fields
    return false unless check_in&.teammate
    return false unless current_user.is_a?(CompanyTeammate)
    current_user.person == check_in.teammate.person || admin_bypass?
  end

  def can_update_manager_check_in_fields?(check_in)
    # Manager can update manager fields if they have management permissions
    return false unless current_user
    return true if admin_bypass?
    
    # If person is nil, we can't check permissions
    return false unless person
    
    # If check_in is nil, we're creating a new check-in
    # Manager can create check-ins for people they manage
    if check_in.nil?
      # current_user should be a CompanyTeammate
      return false unless current_user.is_a?(CompanyTeammate)
      pundit_user = OpenStruct.new(user: current_user, real_user: current_user)
      policy = PersonPolicy.new(pundit_user, person)
      return policy.manage_assignments?
    end
    
    # If check_in exists, check if manager can update manager fields
    return false unless check_in&.teammate
    
    # Check if current user can manage this person's assignments
    # current_user should be a CompanyTeammate
    return false unless current_user.is_a?(CompanyTeammate)
    pundit_user = OpenStruct.new(user: current_user, real_user: current_user)
    policy = PersonPolicy.new(pundit_user, check_in.teammate.person)
    policy.manage_assignments?
  end

  def can_finalize_check_in?(check_in)
    # Only managers can finalize check-ins
    return false unless current_user
    return true if admin_bypass?
    
    # If person is nil, we can't check permissions
    return false unless person
    
    # If check_in is nil, we're creating a new check-in
    # Manager can finalize check-ins for people they manage
    if check_in.nil?
      # current_user should be a CompanyTeammate
      return false unless current_user.is_a?(CompanyTeammate)
      pundit_user = OpenStruct.new(user: current_user, real_user: current_user)
      policy = PersonPolicy.new(pundit_user, person)
      return policy.manage_assignments?
    end
    
    # If check_in exists, check if manager can finalize
    return false unless check_in&.teammate
    
    # Check if current user can manage this person's assignments
    # current_user should be a CompanyTeammate
    return false unless current_user.is_a?(CompanyTeammate)
    pundit_user = OpenStruct.new(user: current_user, real_user: current_user)
    policy = PersonPolicy.new(pundit_user, check_in.teammate.person)
    policy.manage_assignments?
  end

  private

  def admin_bypass?
    return false unless current_user
    
    # Handle both Teammate and Person objects
    if current_user.is_a?(Teammate)
      current_user.person&.og_admin?
    elsif current_user.is_a?(Person)
      current_user.og_admin?
    else
      false
    end
  end

  def milestone_has_changes?(milestone)
    return false unless maap_snapshot&.maap_data&.dig('milestones')
    
    proposed_data = maap_snapshot.maap_data['milestones'].find { |m| m['ability_id'] == milestone.ability_id }
    return false unless proposed_data
    
    previous_milestones = previous_snapshot&.maap_data&.dig('milestones') || []
    previous_data = previous_milestones.find { |m| m['ability_id'] == milestone.ability_id }
    
    return true unless previous_data
    
    previous_data['milestone_level'] != proposed_data['milestone_level'] ||
    previous_data['certifying_teammate_id'].to_s != proposed_data['certifying_teammate_id'].to_s ||
    previous_data['attained_at'].to_s != proposed_data['attained_at'].to_s
  end
end
