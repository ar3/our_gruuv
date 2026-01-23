class InitialMaapSnapshotService
  class InitialSnapshotError < StandardError; end

  def initialize(company_teammate:)
    @company_teammate = company_teammate
    @person = company_teammate.person
    @organization = company_teammate.organization
  end

  def create_initial_snapshot
    # Check if snapshot already exists (idempotency)
    existing_snapshot = MaapSnapshot.for_employee_teammate(@company_teammate).first
    return { success: true, snapshot: existing_snapshot, message: 'Initial snapshot already exists' } if existing_snapshot

    # Validate prerequisites
    validation_result = validate_prerequisites
    return validation_result unless validation_result[:success]

    # Get active employment tenure
    active_tenure = @company_teammate.employment_tenures.active.where(company: @organization).first
    position = active_tenure.position

    # Build maap_data with custom assignments
    maap_data = build_initial_maap_data(active_tenure, position)

    # Find or create OG Automation teammate
    og_automation_teammate = find_or_create_og_automation_teammate

    # Create the snapshot
    snapshot = MaapSnapshot.create!(
      employee_company_teammate: @company_teammate,
      creator_company_teammate: og_automation_teammate,
      company: @organization,
      change_type: 'assignment_management',
      reason: 'Initial expectation',
      maap_data: maap_data,
      manager_request_info: {}
    )

    { success: true, snapshot: snapshot, message: 'Initial snapshot created successfully' }
  end

  private

  attr_reader :company_teammate, :person, :organization

  def validate_prerequisites
    # Check 1: No existing MAAP snapshots
    if MaapSnapshot.for_employee_teammate(@company_teammate).exists?
      return { success: false, message: 'Company teammate already has MAAP snapshots' }
    end

    # Check 2: Has active employment tenure
    active_tenure = @company_teammate.employment_tenures.active.where(company: @organization).first
    unless active_tenure
      return { success: false, message: 'Company teammate has no active employment tenure' }
    end

    position = active_tenure.position
    unless position
      return { success: false, message: 'Active employment tenure has no position' }
    end

    # Check 3: Position has required assignments
    required_assignments = position.required_assignments
    unless required_assignments.exists?
      return { success: false, message: 'Position has no required assignments' }
    end

    # Check 4: All required assignments have min and/or max energy values
    missing_energy_assignments = required_assignments.select do |pa|
      pa.min_estimated_energy.nil? && pa.max_estimated_energy.nil?
    end

    if missing_energy_assignments.any?
      assignment_titles = missing_energy_assignments.map { |pa| pa.assignment.title }.join(', ')
      return { 
        success: false, 
        message: "One or more required position assignments missing min/max energy values: #{assignment_titles}" 
      }
    end

    { success: true }
  end

  def build_initial_maap_data(active_tenure, position)
    # Build base maap_data using existing method
    base_data = MaapSnapshot.build_maap_data_for_teammate(@company_teammate)

    # Override assignments with only required position assignments
    required_assignments = position.required_assignments.includes(:assignment)
    assignments_data = required_assignments.map do |position_assignment|
      {
        assignment_id: position_assignment.assignment_id,
        anticipated_energy_percentage: position_assignment.anticipated_energy_percentage,
        rated_assignment: {}
      }
    end

    # Update assignments in base_data (Rails will handle key conversion for JSONB)
    base_data['assignments'] = assignments_data
    base_data
  end

  def find_or_create_og_automation_teammate
    # Try to find existing OG Automation person by id first
    og_automation_person = Person.find_by(id: -1)
    
    unless og_automation_person
      # Try to find by email as fallback
      og_automation_person = Person.find_by(email: 'automation@og.local')
      if og_automation_person && og_automation_person.id != -1
        # Update existing person's id to -1
        Person.connection.execute(
          "UPDATE people SET id = -1 WHERE id = #{og_automation_person.id}"
        )
        # Reset the sequence if needed (PostgreSQL specific)
        max_id = Person.where('id > 0').maximum(:id) || 0
        Person.connection.execute(
          "SELECT setval('people_id_seq', #{max_id})"
        )
        og_automation_person = Person.find(-1)
      end
    end

    unless og_automation_person
      # Create new person - we'll set id after creation
      Person.transaction do
        # Create person with auto-generated id
        og_automation_person = Person.create!(
          first_name: 'OG',
          last_name: 'Automation',
          email: 'automation@og.local'
        )
        
        # Update the id to -1
        Person.connection.execute(
          "UPDATE people SET id = -1 WHERE id = #{og_automation_person.id}"
        )
        
        # Reset sequence to continue from max positive id
        max_id = Person.where('id > 0').maximum(:id) || 0
        Person.connection.execute(
          "SELECT setval('people_id_seq', #{max_id})"
        )
      end
      
      # Return the person with id = -1
      og_automation_person = Person.find(-1)
    end
    
    # Now find or create the CompanyTeammate for this person in this organization
    CompanyTeammate.find_or_create_by!(
      person: og_automation_person,
      organization: @organization
    )
  rescue ActiveRecord::RecordNotUnique, PG::UniqueViolation, ActiveRecord::RecordNotFound
    # If another process created it during our transaction, find it
    og_person = Person.find_by(id: -1) || Person.find_by(email: 'automation@og.local')
    CompanyTeammate.find_or_create_by!(
      person: og_person,
      organization: @organization
    )
  end
end

