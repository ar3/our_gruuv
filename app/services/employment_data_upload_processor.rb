class EmploymentDataUploadProcessor
  attr_reader :upload_event, :organization, :results

  def initialize(upload_event, organization)
    @upload_event = upload_event
    @organization = organization
    @results = { successes: [], failures: [] }
  end

  def process
    return false unless upload_event.can_process?
    
    upload_event.mark_as_processing!
    
    begin
      # Process each section of data
      process_people
      process_assignments
      process_assignment_tenures
      process_assignment_check_ins
      process_external_references
      
      # Mark as completed with results
      upload_event.mark_as_completed!(@results)
      true
    rescue => e
      # Mark as failed with error
      upload_event.mark_as_failed!(e.message)
      false
    end
  end

  private

  def process_people
    return unless upload_event.preview_actions['people']
    
    upload_event.preview_actions['people'].each do |person_data|
      begin
        Rails.logger.debug "Processing person: #{person_data.inspect}"
        person, was_created = find_or_create_person(person_data)
        @results[:successes] << {
          type: 'person',
          id: person.id,
          action: was_created ? 'created' : 'found',
          name: person.display_name,
          row: person_data['row']
        }
      rescue => e
        @results[:failures] << {
          type: 'person',
          error: e.message,
          data: person_data,
          row: person_data['row']
        }
      end
    end
  end

  def process_assignments
    return unless upload_event.preview_actions['assignments']
    
    upload_event.preview_actions['assignments'].each do |assignment_data|
      begin
        Rails.logger.debug "Processing assignment: #{assignment_data.inspect}"
        assignment, was_created = find_or_create_assignment(assignment_data)
        @results[:successes] << {
          type: 'assignment',
          id: assignment.id,
          action: was_created ? 'created' : 'found',
          title: assignment.title,
          row: assignment_data['row']
        }
      rescue => e
        @results[:failures] << {
          type: 'assignment',
          error: e.message,
          data: assignment_data,
          row: assignment_data['row']
        }
      end
    end
  end

  def process_assignment_tenures
    return unless upload_event.preview_actions['assignment_tenures']
    
    upload_event.preview_actions['assignment_tenures'].each do |tenure_data|
      begin
        # Find the person and assignment for this tenure based on row number
        person = find_person_by_row(tenure_data['row'])
        assignment = find_assignment_by_row(tenure_data['row'])
        
        Rails.logger.debug "Tenure processing: row=#{tenure_data['row']}, person=#{person&.id}, assignment=#{assignment&.id}"
        
        next unless person && assignment
        
        # Find or create teammate - this is now handled inside find_or_create_assignment_tenure
        tenure, was_created = find_or_create_assignment_tenure(person, assignment, tenure_data)
        @results[:successes] << {
          type: 'assignment_tenure',
          id: tenure.id,
          action: was_created ? 'created' : 'found',
          person_name: person.display_name,
          assignment_title: assignment.title,
          row: tenure_data['row']
        }
      rescue => e
        @results[:failures] << {
          type: 'assignment_tenure',
          error: e.message,
          data: tenure_data,
          row: tenure_data['row']
        }
      end
    end
  end

  def process_assignment_check_ins
    return unless upload_event.preview_actions['assignment_check_ins']
    
    upload_event.preview_actions['assignment_check_ins'].each do |check_in_data|
      begin
        # Find the person and assignment for this check-in based on row number
        person = find_person_by_row(check_in_data['row'])
        assignment = find_assignment_by_row(check_in_data['row'])
        
        Rails.logger.debug "Check-in processing: row=#{check_in_data['row']}, person=#{person&.id}, assignment=#{assignment&.id}"
        
        next unless person && assignment
        
        # Find or create teammate - this is now handled inside find_or_create_assignment_check_in
        check_in, was_created = find_or_create_assignment_check_in(person, assignment, check_in_data)
        @results[:successes] << {
          type: 'assignment_check_in',
          id: check_in.id,
          action: was_created ? 'created' : 'found',
          person_name: person.display_name,
          assignment_title: assignment.title,
          row: check_in_data['row']
        }
      rescue => e
        @results[:failures] << {
          type: 'assignment_check_in',
          error: e.message,
          data: check_in_data,
          row: check_in_data['row']
        }
      end
    end
  end

  def process_external_references
    return unless upload_event.preview_actions['external_references']
    
    upload_event.preview_actions['external_references'].each do |ref_data|
      begin
        Rails.logger.info "Processing external reference for assignment name: '#{ref_data['assignment_name']}'"
        # Find the assignment for this external reference
        assignment = find_assignment_by_name(ref_data['assignment_name'])
        next unless assignment
        
        external_ref, was_created = find_or_create_external_reference(assignment, ref_data)
        @results[:successes] << {
          type: 'external_reference',
          id: external_ref.id,
          action: was_created ? 'created' : 'found',
          assignment_title: assignment.title,
          url: external_ref.url,
          row: ref_data['row']
        }
      rescue => e
        @results[:failures] << {
          type: 'external_reference',
          error: e.message,
          data: ref_data,
          row: ref_data['row']
        }
      end
    end
  end

  def find_or_create_person(person_data)
    # Try to find by email first
    if person_data['email'].present?
      person = Person.find_by(email: person_data['email'])
      return person, false if person
    end
    
    # Try to find by name (less reliable but fallback)
    if person_data['name'].present?
      # Use FullNameParser for consistent name parsing
      name_parts = FullNameParser.new(person_data['name'])
      
      person = Person.find_by(
        first_name: name_parts.first_name,
        last_name: name_parts.last_name
      )
      return person, false if person
    end
    
    # Create new person if not found
    if person_data['name'].present?
      name_parts = FullNameParser.new(person_data['name'])
      person = Person.create!(
        first_name: name_parts.first_name,
        middle_name: name_parts.middle_name,
        last_name: name_parts.last_name,
        suffix: name_parts.suffix,
        email: person_data['email'].presence || "unknown_#{SecureRandom.hex(4)}@example.com"
      )
    else
      person = Person.create!(
        first_name: 'Unknown',
        last_name: 'Unknown',
        email: person_data['email'].presence || "unknown_#{SecureRandom.hex(4)}@example.com"
      )
    end
    
    return person, true
  end

  def find_or_create_assignment(assignment_data)
    # Try to find by assignment_name (from parser) or title
    assignment_name = assignment_data['assignment_name'] || assignment_data['title']
    
    Rails.logger.info "=== ASSIGNMENT LOOKUP DEBUG ==="
    Rails.logger.info "Input data: #{assignment_data.inspect}"
    Rails.logger.info "Organization: #{organization.inspect}"
    Rails.logger.info "Assignment name: '#{assignment_name}'"
    
    # Strip HTML from assignment name
    if assignment_name.present?
      clean_assignment_name = strip_html(assignment_name)
      Rails.logger.info "Assignment name: '#{assignment_name}' -> cleaned: '#{clean_assignment_name}'"
      
      assignment = Assignment.find_by(
        title: clean_assignment_name,
        company: organization
      )
      Rails.logger.info "Lookup result: #{assignment.inspect}"
      return assignment, false if assignment
    else
      clean_assignment_name = 'Unknown Assignment'
    end
    
    # Create new assignment if not found
    assignment = Assignment.create!(
      title: clean_assignment_name,
      tagline: assignment_data['assignment_description'] || assignment_data['tagline'] || 'No description provided',
      company: organization
    )
    return assignment, true
  end

  def find_or_create_assignment_tenure(person, assignment, tenure_data)
    # Find or create teammate for this person and assignment's company
    teammate = find_or_create_teammate(person, assignment.company)
    
    Rails.logger.info "=== TENURE LOGIC FOR TEAMMATE #{teammate.id} (PERSON #{person.id} - #{person.display_name}) AND ASSIGNMENT #{assignment.id} (#{assignment.title}) ==="
    
    # Determine the start date for the tenure
    # Priority: 1) tenure_data start date, 2) today
    tenure_start_date = if tenure_data['assignment_tenure_start_date'].present?
      tenure_data['assignment_tenure_start_date'].to_date
    else
      Date.current
    end
    Rails.logger.info "Tenure start date: #{tenure_start_date} (from data: #{tenure_data['assignment_tenure_start_date']}, fallback: #{Date.current})"
    
    # Find the most recent active tenure for this teammate and assignment
    existing_tenure = AssignmentTenure.most_recent_for(teammate, assignment)
    
    if existing_tenure
      Rails.logger.info "Found existing tenure: #{existing_tenure.id} (started: #{existing_tenure.started_at}, energy: #{existing_tenure.anticipated_energy_percentage})"
      
      # Check if we need to create a new tenure (energy or manager changed)
      new_energy = tenure_data['anticipated_energy_percentage']
      energy_changed = existing_tenure.anticipated_energy_percentage != new_energy
      
      Rails.logger.info "New energy: #{new_energy}, Energy changed: #{energy_changed}"
      
      # For now, we'll assume manager changes aren't tracked in this data
      # If you need to track manager changes, you'll need to add that field to the upload data
      
      if energy_changed
        Rails.logger.info "Energy changed, closing existing tenure and creating new one"
        
        # Close the existing tenure and start a new one
        existing_tenure.update!(ended_at: tenure_start_date)
        Rails.logger.info "Closed existing tenure #{existing_tenure.id} at #{existing_tenure.ended_at}"
        
        # Create new tenure starting on the check-in date
        tenure = AssignmentTenure.create!(
          teammate: teammate,
          assignment: assignment,
          started_at: tenure_start_date,
          ended_at: tenure_data['assignment_tenure_end_date'],
          anticipated_energy_percentage: tenure_data['anticipated_energy_percentage']
        )
        Rails.logger.info "Created new tenure: #{tenure.id} (started: #{tenure.started_at}, energy: #{tenure.anticipated_energy_percentage})"
        return tenure, true
      else
        Rails.logger.info "No changes, returning existing tenure"
        # No changes, just return the existing tenure
        return existing_tenure, false
      end
    else
      Rails.logger.info "No existing tenure found, creating new one starting on #{tenure_start_date}"
      
      # Validate required data
      if tenure_data['anticipated_energy_percentage'].nil?
        Rails.logger.warn "Warning: No anticipated energy percentage provided, using nil"
      end
      
      # No existing tenure, create new one starting on the check-in date
      tenure = AssignmentTenure.create!(
        teammate: teammate,
        assignment: assignment,
        started_at: tenure_start_date,
        ended_at: tenure_data['assignment_tenure_end_date'],
        anticipated_energy_percentage: tenure_data['anticipated_energy_percentage']
      )
      Rails.logger.info "Created new tenure: #{tenure.id} (started: #{tenure.started_at}, energy: #{tenure.anticipated_energy_percentage})"
      return tenure, true
    end
  end

  def find_or_create_assignment_check_in(person, assignment, check_in_data)
    # Find or create teammate for this person and assignment's company
    teammate = find_or_create_teammate(person, assignment.company)
    
    # Try to find existing check-in
    check_in = AssignmentCheckIn.find_by(
      teammate: teammate,
      assignment: assignment,
      check_in_started_on: check_in_data['check_in_date']
    )
    return check_in, false if check_in
    
    # Create new check-in if not found
    check_in = AssignmentCheckIn.create!(
      teammate: teammate,
      assignment: assignment,
      check_in_started_on: check_in_data['check_in_date'],
      actual_energy_percentage: check_in_data['energy_percentage'],
      manager_rating: check_in_data['manager_rating'],
      employee_rating: check_in_data['employee_rating'],
      official_rating: check_in_data['official_rating'],
      manager_private_notes: check_in_data['manager_private_notes'],
      employee_private_notes: check_in_data['employee_private_notes'],
      employee_personal_alignment: check_in_data['employee_personal_alignment']
    )
    return check_in, true
  end

  def find_or_create_external_reference(assignment, ref_data)
    # Try to find existing external reference
    external_ref = ExternalReference.find_by(
      referable: assignment,
      reference_type: 'published'
    )
    return external_ref, false if external_ref
    
    # Create new external reference if not found
    external_ref = ExternalReference.create!(
      referable: assignment,
      reference_type: 'published',
      url: ref_data['external_url']
    )
    return external_ref, true
  end

  def find_person_by_row(row_number)
    # Find person by row number from the results
    person_success = @results[:successes].find { |s| s[:type] == 'person' && s[:row] == row_number }
    return nil unless person_success
    
    Person.find(person_success[:id])
  end

  def find_assignment_by_row(row_number)
    # Find assignment by row number from the results
    assignment_success = @results[:successes].find { |s| s[:type] == 'assignment' && s[:row] == row_number }
    return nil unless assignment_success
    
    Assignment.find(assignment_success[:id])
  end

  def find_assignment_by_name(assignment_name)
    # Remove URL and HTML from assignment name for lookup
    Rails.logger.info "Looking up assignment by name: '#{assignment_name}'"
    clean_name = strip_html(assignment_name.gsub(/\[https?:\/\/[^\]]+\]/, '').strip)
    Rails.logger.info "Cleaned assignment name: '#{clean_name}'"
    
    assignment = Assignment.find_by(
      title: clean_name,
      company: organization
    )
    
    if assignment
      Rails.logger.info "Found assignment: #{assignment.id} (#{assignment.title})"
    else
      Rails.logger.info "No assignment found with title: '#{clean_name}'"
    end
    
    assignment
  end

  def find_or_create_teammate(person, organization)
    # Find or create teammate for person and organization
    teammate = Teammate.find_or_create_by(person_id: person.id, organization_id: organization.id) do |t|
      t.can_manage_employment = false
      t.can_manage_maap = false
      t.can_create_employment = false
      t.type = 'CompanyTeammate'
    end
    teammate
  end

  private

  def strip_html(text)
    return text if text.blank?
    
    # Remove HTML tags and entities
    cleaned = text.gsub(/<[^>]*>/, '')           # Remove HTML tags
                  .gsub(/&[a-zA-Z0-9#]+;/, ' ')  # Replace HTML entities with spaces
                  .gsub(/\s+/, ' ')               # Normalize whitespace
                  .strip                          # Remove leading/trailing whitespace
    
    # If the result is empty after cleaning, return the original text
    cleaned.present? ? cleaned : text
  end
end
