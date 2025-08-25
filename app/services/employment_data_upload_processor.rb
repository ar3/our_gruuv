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
        
        # Find the most recent tenure for this person/assignment
        tenure = AssignmentTenure.most_recent_for(person, assignment)
        Rails.logger.debug "Found tenure: #{tenure&.id}"
        next unless tenure
        
        check_in, was_created = find_or_create_assignment_check_in(tenure, check_in_data)
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
    # Try to find by title
    if assignment_data['title'].present?
      assignment = Assignment.find_by(
        title: assignment_data['title'],
        company: organization
      )
      return assignment, false if assignment
    end
    
    # Create new assignment if not found
    assignment = Assignment.create!(
      title: assignment_data['title'] || 'Unknown Assignment',
      tagline: assignment_data['tagline'].presence || 'No description provided',
      company: organization
    )
    return assignment, true
  end

  def find_or_create_assignment_tenure(person, assignment, tenure_data)
    # Try to find existing tenure
    tenure = AssignmentTenure.find_by(
      person: person,
      assignment: assignment,
      started_at: tenure_data['started_at']
    )
    return tenure, false if tenure
    
    # Create new tenure if not found
    tenure = AssignmentTenure.create!(
      person: person,
      assignment: assignment,
      started_at: tenure_data['started_at'],
      ended_at: tenure_data['ended_at'],
      anticipated_energy_percentage: tenure_data['anticipated_energy_percentage']
    )
    return tenure, true
  end

  def find_or_create_assignment_check_in(tenure, check_in_data)
    # Try to find existing check-in
    check_in = AssignmentCheckIn.find_by(
      assignment_tenure: tenure,
      check_in_started_on: check_in_data['check_in_started_on']
    )
    return check_in, false if check_in
    
    # Create new check-in if not found
    check_in = AssignmentCheckIn.create!(
      assignment_tenure: tenure,
      check_in_started_on: check_in_data['check_in_started_on'],
      actual_energy_percentage: check_in_data['actual_energy_percentage'],
      manager_rating: check_in_data['manager_rating'],
      employee_rating: check_in_data['employee_rating'],
      official_rating: check_in_data['official_rating'],
      manager_private_notes: check_in_data['manager_private_notes'],
      employee_private_notes: check_in_data['employee_private_notes']
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
      url: ref_data['url']
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
    # Remove URL from assignment name for lookup
    clean_name = assignment_name.gsub(/\[https?:\/\/[^\]]+\]/, '').strip
    
    Assignment.find_by(
      title: clean_name,
      company: organization
    )
  end
end
