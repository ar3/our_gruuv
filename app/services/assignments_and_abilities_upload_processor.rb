class AssignmentsAndAbilitiesUploadProcessor
  include FlexibleNameMatcher

  attr_reader :bulk_sync_event, :organization, :results, :last_error, :last_error

  def initialize(bulk_sync_event, organization)
    @bulk_sync_event = bulk_sync_event
    @organization = organization
    @results = { successes: [], failures: [] }
    @current_person = bulk_sync_event.creator
    @last_error = nil
  end

  def process
    unless bulk_sync_event.can_process?
      error_msg = "Cannot process bulk_sync_event #{bulk_sync_event.id}. Status: #{bulk_sync_event.status}"
      Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: #{error_msg}"
      @results[:failures] << {
        type: 'system_error',
        error: error_msg
      }
      return false
    end
    
    Rails.logger.info "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Starting processing for bulk_sync_event #{bulk_sync_event.id}"
    bulk_sync_event.mark_as_processing!
    
    begin
      # Process each section of data
      Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Processing abilities..."
      process_abilities
      Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Processing assignments..."
      process_assignments
      Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Processing assignment_abilities..."
      process_assignment_abilities
      Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Processing position_assignments..."
      process_position_assignments
      
      # Mark as completed with results
      Rails.logger.info "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Processing completed. Successes: #{@results[:successes].length}, Failures: #{@results[:failures].length}"
      bulk_sync_event.mark_as_completed!(@results)
      true
    rescue => e
      # Store the error for access by the job
      @last_error = e
      
      # Add the error to failures if not already there
      error_message = e.message.presence || "Unknown error occurred"
      unless @results[:failures].any? { |f| f[:error] == error_message }
        @results[:failures] << {
          type: 'system_error',
          error: "#{e.class.name}: #{error_message}",
          backtrace: e.backtrace&.first(5)
        }
      end
      
      Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Processing failed for bulk_sync_event #{bulk_sync_event.id}: #{error_message}"
      Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Exception class: #{e.class.name}"
      Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Backtrace: #{e.backtrace.first(15).join("\n")}"
      Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Results so far - Successes: #{@results[:successes].length}, Failures: #{@results[:failures].length}"
      bulk_sync_event.mark_as_failed!(error_message)
      # Re-raise the exception so it bubbles up
      raise e
    end
  end

  private

  def process_abilities
    unless bulk_sync_event.preview_actions['abilities']
      Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: No abilities to process"
      return
    end
    
    Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Processing #{bulk_sync_event.preview_actions['abilities'].length} abilities"
    bulk_sync_event.preview_actions['abilities'].each do |ability_data|
      begin
        Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Processing ability: #{ability_data.inspect}"
        ability, was_created = find_or_create_ability(ability_data)
        @results[:successes] << {
          type: 'ability',
          id: ability.id,
          action: was_created ? 'created' : 'found',
          name: ability.name,
          row: ability_data['row']
        }
        Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Ability #{ability.name} #{was_created ? 'created' : 'found'}"
      rescue => e
        Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Failed to process ability: #{ability_data.inspect}"
        Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Error: #{e.message}"
        @results[:failures] << {
          type: 'ability',
          error: e.message,
          data: ability_data,
          row: ability_data['row']
        }
      end
    end
  end

  def process_assignments
    unless bulk_sync_event.preview_actions['assignments']
      Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: No assignments to process"
      return
    end
    
    Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Processing #{bulk_sync_event.preview_actions['assignments'].length} assignments"
    bulk_sync_event.preview_actions['assignments'].each do |assignment_data|
      begin
        Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Processing assignment: #{assignment_data['title']} (row #{assignment_data['row']})"
        assignment, was_created = find_or_create_assignment(assignment_data)
        @results[:successes] << {
          type: 'assignment',
          id: assignment.id,
          action: was_created ? 'created' : 'updated',
          title: assignment.title,
          row: assignment_data['row']
        }
        Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Assignment #{assignment.title} #{was_created ? 'created' : 'updated'}"
      rescue => e
        Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Failed to process assignment: #{assignment_data['title']} (row #{assignment_data['row']})"
        Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Error: #{e.message}"
        Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Assignment data: #{assignment_data.inspect}"
        @results[:failures] << {
          type: 'assignment',
          error: e.message,
          data: assignment_data,
          row: assignment_data['row']
        }
      end
    end
  end

  def process_assignment_abilities
    unless bulk_sync_event.preview_actions['assignment_abilities']
      Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: No assignment_abilities to process"
      return
    end
    
    Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Processing #{bulk_sync_event.preview_actions['assignment_abilities'].length} assignment_abilities"
    bulk_sync_event.preview_actions['assignment_abilities'].each do |aa_data|
      begin
        Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Processing assignment_ability - assignment: #{aa_data['assignment_title']}, ability: #{aa_data['ability_name']}"
        assignment = find_assignment_by_title(aa_data['assignment_title'])
        ability = find_ability_by_name(aa_data['ability_name'])
        
        unless assignment
          Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Assignment not found: #{aa_data['assignment_title']}"
          next
        end
        
        unless ability
          Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Ability not found: #{aa_data['ability_name']}"
          next
        end
        
        # Check if already linked
        existing = AssignmentAbility.find_by(assignment: assignment, ability: ability)
        if existing
          Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: AssignmentAbility already exists, skipping"
          @results[:successes] << {
            type: 'assignment_ability',
            id: existing.id,
            assignment_id: assignment.id,
            ability_id: ability.id,
            action: 'skipped',
            assignment_title: assignment.title,
            ability_name: ability.name,
            row: aa_data['row']
          }
          next
        end
        
        # Create new link
        Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Creating AssignmentAbility link"
        assignment_ability = AssignmentAbility.create!(
          assignment: assignment,
          ability: ability,
          milestone_level: aa_data['milestone_level'] || 1
        )
        Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Created AssignmentAbility (id: #{assignment_ability.id})"
        
        @results[:successes] << {
          type: 'assignment_ability',
          id: assignment_ability.id,
          assignment_id: assignment.id,
          ability_id: ability.id,
          action: 'created',
          assignment_title: assignment.title,
          ability_name: ability.name,
          row: aa_data['row']
        }
      rescue => e
        Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Failed to process assignment_ability: #{aa_data.inspect}"
        Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Error: #{e.message}"
        @results[:failures] << {
          type: 'assignment_ability',
          error: e.message,
          data: aa_data,
          row: aa_data['row']
        }
      end
    end
  end

  def process_position_assignments
    unless bulk_sync_event.preview_actions['position_assignments']
      Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: No position_assignments to process"
      return
    end
    
    Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Processing #{bulk_sync_event.preview_actions['position_assignments'].length} position_assignments"
    bulk_sync_event.preview_actions['position_assignments'].each do |pa_data|
      begin
        Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Processing position_assignment - assignment: #{pa_data['assignment_title']}, position: #{pa_data['position_title']}"
        assignment = find_assignment_by_title(pa_data['assignment_title'])
        unless assignment
          Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Assignment not found: #{pa_data['assignment_title']}"
          next
        end
        
        position, was_position_created = find_or_create_position(pa_data['position_title'])
        unless position
          Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Position not found/created: #{pa_data['position_title']}"
          next
        end
        
        # Track position creation/finding
        @results[:successes] << {
          type: 'position',
          id: position.id,
          title_id: position.title.id,
          action: was_position_created ? 'created' : 'found',
          position_title: position.display_name,
          title_name: position.title.external_title,
          row: pa_data['row']
        }
        
        # Update seat departments if department_names are provided
        if pa_data['department_names'].present?
          update_seat_departments_for_title(position.title, pa_data['department_names'])
        end
        
        # Check if already linked
        existing = PositionAssignment.find_by(position: position, assignment: assignment)
        if existing
          Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: PositionAssignment already exists, checking energy values"
          
          # If both min and max energy are nil or 0, set max_estimated_energy to 5
          if energy_values_nil_or_zero?(existing.min_estimated_energy, existing.max_estimated_energy)
            Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Setting max_estimated_energy to 5 for existing PositionAssignment"
            existing.update!(max_estimated_energy: 5)
          end
          
          @results[:successes] << {
            type: 'position_assignment',
            id: existing.id,
            position_id: position.id,
            assignment_id: assignment.id,
            action: 'skipped',
            assignment_title: assignment.title,
            position_title: position.display_name,
            row: pa_data['row']
          }
          next
        end
        
        # Create new link
        Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Creating PositionAssignment link"
        position_assignment = PositionAssignment.create!(
          position: position,
          assignment: assignment,
          assignment_type: 'required',
          max_estimated_energy: 5
        )
        Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Created PositionAssignment (id: #{position_assignment.id}) with max_estimated_energy: 5"
        
        @results[:successes] << {
          type: 'position_assignment',
          id: position_assignment.id,
          position_id: position.id,
          assignment_id: assignment.id,
          action: 'created',
          assignment_title: assignment.title,
          position_title: position.display_name,
          row: pa_data['row']
        }
      rescue => e
        Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Failed to process position_assignment: #{pa_data.inspect}"
        Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Error: #{e.message}"
        @results[:failures] << {
          type: 'position_assignment',
          error: e.message,
          data: pa_data,
          row: pa_data['row']
        }
      end
    end
  end

  def find_or_create_ability(ability_data)
    ability_name = ability_data['name']
    if ability_name.blank?
      Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Ability name is blank. Data: #{ability_data.inspect}"
      return nil
    end
    
    # Use flexible matching to find existing ability
    ability = find_with_flexible_matching(
      Ability,
      :name,
      ability_name,
      Ability.where(company: organization)
    )
    
    if ability
      Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Found existing ability: #{ability.name} (id: #{ability.id})"
      # Update semantic version using clarifying change
      old_version = ability.semantic_version
      ability.update!(semantic_version: ability.next_minor_version)
      Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Updated ability version from #{old_version} to #{ability.semantic_version}"
      return ability, false
    end
    
    # Create new ability
    Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Creating new ability: #{ability_name}"
    ability = Ability.create!(
      name: ability_name,
      description: "Ability: #{ability_name}",
      company: organization,
      semantic_version: '0.0.1',
      created_by: @current_person,
      updated_by: @current_person
    )
    Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Created ability: #{ability.name} (id: #{ability.id})"
    
    return ability, true
  end

  def find_or_create_assignment(assignment_data)
    assignment_title = assignment_data['title']
    if assignment_title.blank?
      Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Assignment title is blank. Data: #{assignment_data.inspect}"
      return nil
    end
    
    # Use flexible matching to find existing assignment
    assignment = find_with_flexible_matching(
      Assignment,
      :title,
      assignment_title,
      Assignment.where(company: organization)
    )
    
    if assignment
      Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Found existing assignment: #{assignment.title} (id: #{assignment.id})"
      # Update assignment
      required_activities_text = if assignment_data['required_activities'].is_a?(Array)
        assignment_data['required_activities'].join("\n")
      else
        assignment_data['required_activities'] || assignment.required_activities
      end
      
      old_version = assignment.semantic_version
      assignment.update!(
        tagline: assignment_data['tagline'] || assignment.tagline,
        required_activities: required_activities_text,
        semantic_version: assignment.next_minor_version
      )
      Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Updated assignment version from #{old_version} to #{assignment.semantic_version}"
      
      # Process outcomes (add new ones, don't delete existing)
      process_outcomes(assignment, assignment_data['outcomes'] || [])
      
      # Process department association
      process_department_association(assignment, assignment_data['department_names'] || [])
      
      return assignment, false
    end
    
    # Create new assignment
    Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Creating new assignment: #{assignment_title}"
    required_activities_text = if assignment_data['required_activities'].is_a?(Array)
      assignment_data['required_activities'].join("\n")
    else
      assignment_data['required_activities']
    end
    
    assignment = Assignment.create!(
      title: assignment_title,
      tagline: assignment_data['tagline'] || 'No tagline provided',
      required_activities: required_activities_text,
      company: organization,
      semantic_version: '0.0.1'
    )
    Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Created assignment: #{assignment.title} (id: #{assignment.id})"
    
      # Process outcomes
      process_outcomes(assignment, assignment_data['outcomes'] || [])
      
      # Process department association
      process_department_association(assignment, assignment_data['department_names'] || [])
      
      return assignment, true
  end

  def process_outcomes(assignment, outcomes)
    return if outcomes.blank?
    
    # Convert array to newline-separated string for the processor
    outcomes_text = outcomes.map(&:strip).reject(&:blank?).join("\n")
    
    # Use AssignmentOutcomesProcessor to handle outcomes
    # This will skip existing outcomes with exact same description
    processor = AssignmentOutcomesProcessor.new(assignment, outcomes_text)
    processor.process
    
    Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Processed outcomes - Created: #{processor.created_count}, Skipped: #{processor.skipped_count}"
  end

  def find_or_create_position(position_title)
    if position_title.blank?
      Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Position title is blank"
      return nil, false
    end
    
    # Use flexible matching to find Title
    Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Looking for Title: #{position_title}"
    title = find_with_flexible_matching(
      Title,
      :external_title,
      position_title,
      Title.joins(:organization).where(organizations: { id: organization.id })
    )
    
    unless title
      # Title not found - create a new one
      Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Title not found for title: #{position_title} in organization #{organization.id}, creating new Title"
      
      # Find PositionMajorLevel with major_level = 1 (raise error if none exists)
      position_major_level = PositionMajorLevel.where(major_level: 1).first
      unless position_major_level
        error_msg = "No PositionMajorLevel with major_level = 1 found. Cannot create Title: #{position_title}"
        Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: #{error_msg}"
        raise error_msg
      end
      
      # Create new Title with exact title from CSV
      Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Creating new Title: #{position_title} with PositionMajorLevel: #{position_major_level.set_name} (major_level: #{position_major_level.major_level})"
      title = Title.create!(
        external_title: position_title,
        organization: organization,
        position_major_level: position_major_level
      )
      Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Created Title: #{title.external_title} (id: #{title.id})"
    else
      Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Found Title: #{title.external_title} (id: #{title.id})"
    end
    
    # Find existing Position for this Title
    position = Position.find_by(title: title)
    if position
      Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Found existing Position: #{position.display_name} (id: #{position.id})"
      return position, false
    end
    
    # Get first PositionLevel from Title's PositionMajorLevel
    position_level = title.position_major_level.position_levels.order(:level).first
    
    unless position_level
      Rails.logger.warn "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: No PositionLevel found for Title #{title.external_title} (PositionMajorLevel: #{title.position_major_level.id})"
      return nil, false
    end
    
    # Create new Position
    Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Creating new Position for Title #{title.external_title} with PositionLevel #{position_level.level}"
    position = Position.create!(
      title: title,
      position_level: position_level,
      semantic_version: '1.0.0'
    )
    Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Created Position: #{position.display_name} (id: #{position.id})"
    
    return position, true
  end

  def process_department_association(assignment, department_names)
    if department_names.blank?
      Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: No department names provided for assignment #{assignment.title}"
      return
    end
    
    # If multiple department names provided, leave department field untouched
    if department_names.length > 1
      Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Multiple department names provided (#{department_names.inspect}), leaving department field untouched for assignment #{assignment.title}"
      return
    end
    
    dept_name = department_names.first
    Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Processing department association for assignment #{assignment.title} with department: #{dept_name}"
    
    # Find or create department by exact name match
    # Get organization IDs from hierarchy (self_and_descendants returns an array)
    org_ids = organization.self_and_descendants.map(&:id)
    base_scope = Organization.where(id: org_ids, type: 'Department')
    Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Searching in #{org_ids.length} organizations"
    
    # Find department by exact name match (case-insensitive)
    department = base_scope.find_by("LOWER(name) = ?", dept_name.downcase)
    
    if department
      Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Found existing department: #{department.name} (id: #{department.id})"
    else
      # Create new department
      Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Creating new department: #{dept_name}"
      department = Organization.create!(
        name: dept_name,
        parent: organization,
        type: 'Department'
      )
      Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Created department: #{department.name} (id: #{department.id})"
    end
    
    # Set department_id
    Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Setting assignment #{assignment.title} department_id to #{department.id} (#{department.name})"
    assignment.update!(department_id: department.id)
  end

  def find_assignment_by_title(title)
    return nil if title.blank?
    
    find_with_flexible_matching(
      Assignment,
      :title,
      title,
      Assignment.where(company: organization)
    )
  end

  def find_ability_by_name(name)
    return nil if name.blank?
    
    find_with_flexible_matching(
      Ability,
      :name,
      name,
      Ability.where(company: organization)
    )
  end

  def energy_values_nil_or_zero?(min_energy, max_energy)
    (min_energy.nil? || min_energy == 0) && (max_energy.nil? || max_energy == 0)
  end

  def update_seat_departments_for_title(title, department_names)
    if department_names.blank?
      Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: No department names provided for title #{title.external_title}"
      return
    end
    
    # If multiple department names provided, leave department field untouched
    if department_names.length > 1
      Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Multiple department names provided (#{department_names.inspect}), leaving seat department fields untouched for title #{title.external_title}"
      return
    end
    
    dept_name = department_names.first
    Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Processing department association for title #{title.external_title} with department: #{dept_name}"
    
    # Find or create department by exact name match
    org_ids = organization.self_and_descendants.map(&:id)
    base_scope = Organization.where(id: org_ids, type: 'Department')
    Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Searching in #{org_ids.length} organizations"
    
    # Find department by exact name match (case-insensitive)
    department = base_scope.find_by("LOWER(name) = ?", dept_name.downcase)
    
    if department
      Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Found existing department: #{department.name} (id: #{department.id})"
    else
      # Create new department
      Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Creating new department: #{dept_name}"
      department = Organization.create!(
        name: dept_name,
        parent: organization,
        type: 'Department'
      )
      Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Created department: #{department.name} (id: #{department.id})"
    end
    
    # Update title's department_id (department_id was moved from seats to titles)
    # All seats for this title will derive their department from the title
    Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Updating title #{title.external_title} with department_id: #{department.id}"
    
    title.update!(department_id: department.id)
    Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadProcessor: Updated title #{title.external_title} with department_id: #{department.id} (#{department.name})"
  end
end

