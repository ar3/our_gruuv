class AssignmentsBulkUploadProcessor
  include FlexibleNameMatcher

  attr_reader :bulk_sync_event, :organization, :results, :last_error

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
      Rails.logger.error "❌❌❌ AssignmentsBulkUploadProcessor: #{error_msg}"
      @results[:failures] << {
        type: 'system_error',
        error: error_msg
      }
      return false
    end
    
    Rails.logger.info "❌❌❌ AssignmentsBulkUploadProcessor: Starting processing for bulk_sync_event #{bulk_sync_event.id}"
    bulk_sync_event.mark_as_processing!
    
    begin
      # Process assignments
      Rails.logger.debug "❌❌❌ AssignmentsBulkUploadProcessor: Processing assignments..."
      process_assignments
      
      # Mark as completed with results
      Rails.logger.info "❌❌❌ AssignmentsBulkUploadProcessor: Processing completed. Successes: #{@results[:successes].length}, Failures: #{@results[:failures].length}"
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
      
      Rails.logger.error "❌❌❌ AssignmentsBulkUploadProcessor: Processing failed for bulk_sync_event #{bulk_sync_event.id}: #{error_message}"
      Rails.logger.error "❌❌❌ AssignmentsBulkUploadProcessor: Exception class: #{e.class.name}"
      Rails.logger.error "❌❌❌ AssignmentsBulkUploadProcessor: Backtrace: #{e.backtrace.first(15).join("\n")}"
      bulk_sync_event.mark_as_failed!(error_message)
      raise e
    end
  end

  private

  def process_assignments
    unless bulk_sync_event.preview_actions['assignments']
      Rails.logger.debug "❌❌❌ AssignmentsBulkUploadProcessor: No assignments to process"
      return
    end
    
    Rails.logger.debug "❌❌❌ AssignmentsBulkUploadProcessor: Processing #{bulk_sync_event.preview_actions['assignments'].length} assignments"
    bulk_sync_event.preview_actions['assignments'].each do |assignment_data|
      begin
        Rails.logger.debug "❌❌❌ AssignmentsBulkUploadProcessor: Processing assignment: #{assignment_data['title']} (row #{assignment_data['row']})"
        assignment, was_created = find_or_create_assignment(assignment_data)
        
        if assignment
          # Process related data
          process_department(assignment, assignment_data['department'])
          process_position_assignments(assignment, assignment_data['positions'] || [])
          process_assignment_abilities(assignment, assignment_data['milestones'] || [])
          process_outcomes(assignment, assignment_data['outcomes'] || [])
          
          @results[:successes] << {
            type: 'assignment',
            id: assignment.id,
            action: was_created ? 'created' : 'updated',
            title: assignment.title,
            row: assignment_data['row']
          }
          Rails.logger.debug "❌❌❌ AssignmentsBulkUploadProcessor: Assignment #{assignment.title} #{was_created ? 'created' : 'updated'}"
        end
      rescue => e
        Rails.logger.error "❌❌❌ AssignmentsBulkUploadProcessor: Failed to process assignment: #{assignment_data['title']} (row #{assignment_data['row']})"
        Rails.logger.error "❌❌❌ AssignmentsBulkUploadProcessor: Error: #{e.message}"
        Rails.logger.error "❌❌❌ AssignmentsBulkUploadProcessor: Assignment data: #{assignment_data.inspect}"
        @results[:failures] << {
          type: 'assignment',
          error: e.message,
          data: assignment_data,
          row: assignment_data['row']
        }
      end
    end
  end

  def find_or_create_assignment(assignment_data)
    assignment_id = assignment_data['assignment_id']
    assignment_title = assignment_data['title']
    
    # Find by ID first, then by title
    assignment = if assignment_id.present?
      Assignment.find_by(id: assignment_id, company: organization.self_and_descendants)
    end
    
    assignment ||= if assignment_title.present?
      find_with_flexible_matching(
        Assignment,
        :title,
        assignment_title,
        Assignment.where(company: organization.self_and_descendants)
      )
    end
    
    if assignment
      Rails.logger.debug "❌❌❌ AssignmentsBulkUploadProcessor: Found existing assignment: #{assignment.title} (id: #{assignment.id})"
      
      # Update assignment fields
      update_attrs = {}
      update_attrs[:title] = assignment_title if assignment_title.present? && assignment_title != assignment.title
      update_attrs[:tagline] = assignment_data['tagline'] if assignment_data['tagline'].present?
      update_attrs[:required_activities] = assignment_data['required_activities'] if assignment_data['required_activities'].present?
      update_attrs[:handbook] = assignment_data['handbook'] if assignment_data['handbook'].present?
      
      # Handle version
      uploaded_version = assignment_data['version']&.strip
      if uploaded_version.present?
        if uploaded_version == assignment.semantic_version
          # Same version - do insignificant change (patch bump)
          update_attrs[:semantic_version] = assignment.next_patch_version
        else
          # Different version - update to uploaded version
          update_attrs[:semantic_version] = uploaded_version
        end
      else
        # No version provided - treat as same version and do patch bump
        update_attrs[:semantic_version] = assignment.next_patch_version
      end
      
      assignment.update!(update_attrs) if update_attrs.any?
      
      return assignment, false
    end
    
    # Create new assignment
    Rails.logger.debug "❌❌❌ AssignmentsBulkUploadProcessor: Creating new assignment: #{assignment_title}"
    
    if assignment_title.blank?
      raise "Assignment title is required for new assignments"
    end
    
    assignment = Assignment.create!(
      title: assignment_title,
      tagline: assignment_data['tagline'] || 'No tagline provided',
      required_activities: assignment_data['required_activities'],
      handbook: assignment_data['handbook'],
      company: organization,
      semantic_version: assignment_data['version'] || '0.0.1'
    )
    Rails.logger.debug "❌❌❌ AssignmentsBulkUploadProcessor: Created assignment: #{assignment.title} (id: #{assignment.id})"
    
    return assignment, true
  end

  def process_department(assignment, department_name)
    return if department_name.blank?
    
    Rails.logger.debug "❌❌❌ AssignmentsBulkUploadProcessor: Processing department for assignment #{assignment.title}: #{department_name}"
    
    # Use DepartmentNameInterpreter to handle hierarchical department names
    interpreter = DepartmentNameInterpreter.new(department_name, organization)
    department = interpreter.interpret
    
    # If department is nil, it means the name matched the company exactly
    # Set department_id to nil (assignment belongs to company, not a department)
    assignment.update!(department_id: department&.id)
    
    if department
      Rails.logger.debug "❌❌❌ AssignmentsBulkUploadProcessor: Set assignment #{assignment.title} department to #{department.name} (id: #{department.id})"
    else
      Rails.logger.debug "❌❌❌ AssignmentsBulkUploadProcessor: Department name matches company - assignment #{assignment.title} belongs to company directly (department_id: nil)"
    end
  end

  def process_position_assignments(assignment, positions_data)
    # Delete existing position assignments
    assignment.position_assignments.destroy_all
    
    positions_data.each do |position_data|
      external_title = position_data['external_title']
      level = position_data['level']
      assignment_type = position_data['assignment_type'] || 'required'
      min_energy = position_data['min_estimated_energy']
      max_energy = position_data['max_estimated_energy']
      
      next if external_title.blank? || level.blank?
      
      # Find or create position
      position, _ = find_or_create_position_by_title_and_level(external_title, level)
      next unless position
      
      # Create position assignment
      PositionAssignment.create!(
        position: position,
        assignment: assignment,
        assignment_type: assignment_type,
        min_estimated_energy: min_energy,
        max_estimated_energy: max_energy
      )
    end
  end

  def find_or_create_position_by_title_and_level(external_title, level)
    # Find or create Title
    org_ids = organization.self_and_descendants.map(&:id)
    title = find_with_flexible_matching(
      Title,
      :external_title,
      external_title,
      Title.joins(:organization).where(organizations: { id: org_ids })
    )
    
    unless title
      # Create new Title
      position_major_level = PositionMajorLevel.where(major_level: 1).first
      unless position_major_level
        raise "No PositionMajorLevel with major_level = 1 found. Cannot create Title: #{external_title}"
      end
      
      title = Title.create!(
        external_title: external_title,
        organization: organization,
        position_major_level: position_major_level
      )
    end
    
    # Find or create PositionLevel
    position_level = title.position_major_level.position_levels.find_by(level: level)
    
    unless position_level
      # Create new PositionLevel
      position_level = PositionLevel.create!(
        position_major_level: title.position_major_level,
        level: level
      )
    end
    
    # Find or create Position
    position = Position.find_by(title: title, position_level: position_level)
    
    unless position
      position = Position.create!(
        title: title,
        position_level: position_level,
        semantic_version: '1.0.0'
      )
    end
    
    [position, false]
  end

  def process_assignment_abilities(assignment, milestones_data)
    # Delete existing assignment abilities
    assignment.assignment_abilities.destroy_all
    
    milestones_data.each do |milestone_data|
      ability_name = milestone_data['ability_name']
      milestone_level = milestone_data['milestone_level']
      
      next if ability_name.blank? || milestone_level.blank?
      
      # Find or create ability
      ability = find_with_flexible_matching(
        Ability,
        :name,
        ability_name,
        Ability.where(organization: organization)
      )
      
      unless ability
        # Create new ability
        ability = Ability.create!(
          name: ability_name,
          description: "Ability: #{ability_name}",
          organization: organization,
          semantic_version: '0.0.1',
          created_by: @current_person,
          updated_by: @current_person
        )
      end
      
      # Create assignment ability
      AssignmentAbility.create!(
        assignment: assignment,
        ability: ability,
        milestone_level: milestone_level
      )
    end
  end

  def process_outcomes(assignment, outcomes_data)
    return if outcomes_data.blank?
    
    # Convert array to newline-separated string for the processor
    outcomes_text = outcomes_data.map(&:strip).reject(&:blank?).join("\n")
    
    # Use AssignmentOutcomesProcessor to handle outcomes
    # This will skip existing outcomes with exact same description
    processor = AssignmentOutcomesProcessor.new(assignment, outcomes_text)
    processor.process
  end
end
