class MaapChangeDetectionService
  def initialize(person:, maap_snapshot:)
    @person = person
    @maap_snapshot = maap_snapshot
  end

  # Returns a hash with counts of changes by category
  def change_counts
    {
      employment: employment_changes_count,
      assignments: assignment_changes_count,
      milestones: milestone_changes_count,
      aspirations: 0 # Coming soon
    }
  end

  # Returns detailed change information for debugging
  def detailed_changes
    {
      employment: employment_changes_detail,
      assignments: assignment_changes_detail,
      milestones: milestone_changes_detail
    }
  end

  def assignment_has_changes?(assignment)
    return false unless maap_snapshot&.maap_data&.dig('assignments')
    
    proposed_data = maap_snapshot.maap_data['assignments'].find { |a| a['id'] == assignment.id }
    return false unless proposed_data
    
    current_tenure = person.assignment_tenures.where(assignment: assignment).active.first
    proposed_tenure = proposed_data['tenure']
    
    # Check tenure changes
    tenure_changed = if current_tenure
      # Active tenure exists - check if energy or start date changed
      current_tenure.anticipated_energy_percentage != proposed_tenure['anticipated_energy_percentage'] ||
      current_tenure.started_at.to_date != Date.parse(proposed_tenure['started_at'])
    else
      # No active tenure - check if we're creating a new one
      if proposed_tenure['anticipated_energy_percentage'] > 0
        # Creating new tenure - this is a change
        true
      else
        # Proposing 0% energy with no active tenure - this is NOT a change
        # The tenure was already ended, so proposing 0% just confirms the current state
        false
      end
    end
    
    # Check check-in changes
    check_in_changed = check_in_has_changes?(assignment, proposed_data)
    
    tenure_changed || check_in_changed
  end

  private

  attr_reader :person, :maap_snapshot

  def employment_changes_count
    employment_has_changes? ? 1 : 0
  end

  def assignment_changes_count
    return 0 unless maap_snapshot&.maap_data&.dig('assignments')
    
    assignment_data = load_assignment_data
    assignment_data.count { |data| assignment_has_changes?(data[:assignment]) }
  end

  def milestone_changes_count
    return 0 unless maap_snapshot&.maap_data&.dig('milestones')
    
    person.person_milestones.count { |milestone| milestone_has_changes?(milestone) }
  end

  def employment_changes_detail
    return { has_changes: false, details: [] } unless maap_snapshot&.maap_data&.dig('employment_tenure')
    
    current = person.employment_tenures.active.first
    proposed = maap_snapshot.maap_data['employment_tenure']
    
    changes = []
    
    if current
      if current.position_id.to_s != proposed['position_id'].to_s
        changes << { field: 'position', current: current.position_id, proposed: proposed['position_id'] }
      end
      if current.manager_id.to_s != proposed['manager_id'].to_s
        changes << { field: 'manager', current: current.manager_id, proposed: proposed['manager_id'] }
      end
      if current.started_at.to_date != Date.parse(proposed['started_at'])
        changes << { field: 'started_at', current: current.started_at.to_date, proposed: Date.parse(proposed['started_at']) }
      end
      if current.seat_id.to_s != proposed['seat_id'].to_s
        changes << { field: 'seat', current: current.seat_id, proposed: proposed['seat_id'] }
      end
    else
      changes << { field: 'employment', current: 'none', proposed: 'new employment' }
    end
    
    { has_changes: changes.any?, details: changes }
  end

  def assignment_changes_detail
    return { has_changes: false, details: [] } unless maap_snapshot&.maap_data&.dig('assignments')
    
    assignment_data = load_assignment_data
    changes = []
    
    assignment_data.each do |data|
      assignment = data[:assignment]
      proposed_data = maap_snapshot.maap_data['assignments'].find { |a| a['id'] == assignment.id }
      next unless proposed_data
      
      assignment_changes = []
      
      # Check tenure changes
      current_tenure = person.assignment_tenures.where(assignment: assignment).active.first
      proposed_tenure = proposed_data['tenure']
      
      if current_tenure
        if current_tenure.anticipated_energy_percentage != proposed_tenure['anticipated_energy_percentage']
          assignment_changes << {
            field: 'anticipated_energy_percentage',
            current: current_tenure.anticipated_energy_percentage,
            proposed: proposed_tenure['anticipated_energy_percentage']
          }
        end
        if current_tenure.started_at.to_date != Date.parse(proposed_tenure['started_at'])
          assignment_changes << {
            field: 'started_at',
            current: current_tenure.started_at.to_date,
            proposed: Date.parse(proposed_tenure['started_at'])
          }
        end
      else
        if proposed_tenure['anticipated_energy_percentage'] > 0
          assignment_changes << {
            field: 'new_tenure',
            current: 'none',
            proposed: proposed_tenure['anticipated_energy_percentage']
          }
        else
          # Proposing 0% energy with no active tenure - this is NOT a change
          # The tenure was already ended, so proposing 0% just confirms the current state
          # No changes to add
        end
      end
      
      # Check check-in changes
      check_in_changes = check_in_changes_detail(assignment, proposed_data)
      assignment_changes.concat(check_in_changes)
      
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

  def check_in_changes_detail(assignment, proposed_data)
    current_check_in = AssignmentCheckIn.where(person: person, assignment: assignment).open.first
    changes = []
    
    # Employee check-in changes
    if proposed_data['employee_check_in']
      employee_data = proposed_data['employee_check_in']
      
      if current_check_in
        if current_check_in.actual_energy_percentage != employee_data['actual_energy_percentage']
          changes << { field: 'employee_actual_energy', current: current_check_in.actual_energy_percentage, proposed: employee_data['actual_energy_percentage'] }
        end
        if current_check_in.employee_rating != employee_data['employee_rating']
          changes << { field: 'employee_rating', current: current_check_in.employee_rating, proposed: employee_data['employee_rating'] }
        end
        if current_check_in.employee_personal_alignment != employee_data['personal_alignment']
          changes << { field: 'personal_alignment', current: current_check_in.employee_personal_alignment, proposed: employee_data['personal_alignment'] }
        end
        if current_check_in.employee_private_notes != employee_data['employee_private_notes']
          changes << { field: 'employee_private_notes', current: current_check_in.employee_private_notes, proposed: employee_data['employee_private_notes'] }
        end
        if (current_check_in.employee_completed? || false) != employee_data['employee_completed_at'].present?
          changes << { field: 'employee_completion', current: current_check_in.employee_completed?, proposed: employee_data['employee_completed_at'].present? }
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
      
      if current_check_in
        if current_check_in.manager_rating != manager_data['manager_rating']
          changes << { field: 'manager_rating', current: current_check_in.manager_rating, proposed: manager_data['manager_rating'] }
        end
        if current_check_in.manager_private_notes != manager_data['manager_private_notes']
          changes << { field: 'manager_private_notes', current: current_check_in.manager_private_notes, proposed: manager_data['manager_private_notes'] }
        end
        if (current_check_in.manager_completed? || false) != manager_data['manager_completed_at'].present?
          changes << { field: 'manager_completion', current: current_check_in.manager_completed?, proposed: manager_data['manager_completed_at'].present? }
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
      
      if current_check_in
        if current_check_in.official_rating != official_data['official_rating']
          changes << { field: 'official_rating', current: current_check_in.official_rating, proposed: official_data['official_rating'] }
        end
        if current_check_in.shared_notes != official_data['shared_notes']
          changes << { field: 'shared_notes', current: current_check_in.shared_notes, proposed: official_data['shared_notes'] }
        end
        if (current_check_in.officially_completed? || false) != official_data['official_check_in_completed_at'].present?
          changes << { field: 'official_completion', current: current_check_in.officially_completed?, proposed: official_data['official_check_in_completed_at'].present? }
        end
        if current_check_in.finalized_by_id.to_s != official_data['finalized_by_id'].to_s
          changes << { field: 'finalized_by', current: current_check_in.finalized_by_id, proposed: official_data['finalized_by_id'] }
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
    return { has_changes: false, details: [] } unless maap_snapshot&.maap_data&.dig('milestones')
    
    changes = []
    
    person.person_milestones.each do |milestone|
      proposed_data = maap_snapshot.maap_data['milestones'].find { |m| m['ability_id'] == milestone.ability_id }
      next unless proposed_data
      
      milestone_changes = []
      
      if milestone.milestone_level != proposed_data['milestone_level']
        milestone_changes << { field: 'milestone_level', current: milestone.milestone_level, proposed: proposed_data['milestone_level'] }
      end
      if milestone.certified_by_id.to_s != proposed_data['certified_by_id'].to_s
        milestone_changes << { field: 'certified_by', current: milestone.certified_by_id, proposed: proposed_data['certified_by_id'] }
      end
      if milestone.attained_at.to_s != proposed_data['attained_at'].to_s
        milestone_changes << { field: 'attained_at', current: milestone.attained_at, proposed: proposed_data['attained_at'] }
      end
      
      if milestone_changes.any?
        changes << {
          ability: milestone.ability.title,
          ability_id: milestone.ability_id,
          changes: milestone_changes
        }
      end
    end
    
    { has_changes: changes.any?, details: changes }
  end

  def load_assignment_data
    # Get all assignments that have tenures OR are in the snapshot
    assignment_ids_from_tenures = person.assignment_tenures.distinct.pluck(:assignment_id)
    assignment_ids_from_snapshot = maap_snapshot.maap_data['assignments'].map { |a| a['id'] }
    all_assignment_ids = (assignment_ids_from_tenures + assignment_ids_from_snapshot).uniq
    
    assignments = Assignment.where(id: all_assignment_ids).includes(:assignment_tenures)
    
    assignments.map do |assignment|
      {
        assignment: assignment,
        active_tenure: person.assignment_tenures.where(assignment: assignment).active.first,
        open_check_in: AssignmentCheckIn.where(person: person, assignment: assignment).open.first
      }
    end
  end

  def employment_has_changes?
    return false unless maap_snapshot&.maap_data&.dig('employment_tenure')
    
    current = person.employment_tenures.active.first
    proposed = maap_snapshot.maap_data['employment_tenure']
    
    return true unless current
    
    current.position_id.to_s != proposed['position_id'].to_s ||
    current.manager_id.to_s != proposed['manager_id'].to_s ||
    current.started_at.to_date != Date.parse(proposed['started_at']) ||
    current.seat_id.to_s != proposed['seat_id'].to_s
  end


  def check_in_has_changes?(assignment, proposed_data)
    current_check_in = AssignmentCheckIn.where(person: person, assignment: assignment).open.first
    
    # Check employee check-in changes
    if proposed_data['employee_check_in']
      employee_changed = if current_check_in
        current_check_in.actual_energy_percentage != proposed_data['employee_check_in']['actual_energy_percentage'] ||
        current_check_in.employee_rating != proposed_data['employee_check_in']['employee_rating'] ||
        current_check_in.employee_personal_alignment != proposed_data['employee_check_in']['personal_alignment'] ||
        current_check_in.employee_private_notes != proposed_data['employee_check_in']['employee_private_notes'] ||
        (current_check_in.employee_completed? || false) != proposed_data['employee_check_in']['employee_completed_at'].present?
      else
        proposed_data['employee_check_in'].values.any? { |v| v.present? }
      end
      return true if employee_changed
    end
    
    # Check manager check-in changes
    if proposed_data['manager_check_in']
      manager_changed = if current_check_in
        current_check_in.manager_rating != proposed_data['manager_check_in']['manager_rating'] ||
        current_check_in.manager_private_notes != proposed_data['manager_check_in']['manager_private_notes'] ||
        (current_check_in.manager_completed? || false) != proposed_data['manager_check_in']['manager_completed_at'].present?
      else
        proposed_data['manager_check_in'].values.any? { |v| v.present? }
      end
      return true if manager_changed
    end
    
    # Check official check-in changes
    if proposed_data['official_check_in']
      official_changed = if current_check_in
        current_check_in.official_rating != proposed_data['official_check_in']['official_rating'] ||
        current_check_in.shared_notes != proposed_data['official_check_in']['shared_notes'] ||
        (current_check_in.officially_completed? || false) != proposed_data['official_check_in']['official_check_in_completed_at'].present? ||
        current_check_in.finalized_by_id.to_s != proposed_data['official_check_in']['finalized_by_id'].to_s
      else
        proposed_data['official_check_in'].values.any? { |v| v.present? }
      end
      return true if official_changed
    end
    
    false
  end

  def milestone_has_changes?(milestone)
    return false unless maap_snapshot&.maap_data&.dig('milestones')
    
    proposed_data = maap_snapshot.maap_data['milestones'].find { |m| m['ability_id'] == milestone.ability_id }
    return false unless proposed_data
    
    milestone.milestone_level != proposed_data['milestone_level'] ||
    milestone.certified_by_id.to_s != proposed_data['certified_by_id'].to_s ||
    milestone.attained_at.to_s != proposed_data['attained_at'].to_s
  end
end
