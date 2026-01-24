class UnassignedEmployeeUploadProcessor
  attr_reader :bulk_sync_event, :organization, :parser, :results

  def initialize(bulk_sync_event, organization)
    @bulk_sync_event = bulk_sync_event
    @organization = organization
    @parser = UnassignedEmployeeUploadParser.new(bulk_sync_event.source_contents)
    @results = {
      successes: [],
      failures: [],
      summary: {
        total_processed: 0,
        successful_creates: 0,
        successful_updates: 0,
        failed_operations: 0
      }
    }
  end

  def process
    unless parser.parse
      results[:failures] << {
        type: 'system_error',
        error: "Parser failed: #{parser.errors.join(', ')}"
      }
      return false
    end

    parsed_data = parser.parsed_data

    ActiveRecord::Base.transaction do
      # Process departments first
      process_departments(parsed_data[:departments] || [])

      # Process managers
      process_managers(parsed_data[:managers] || [])

      # Process unassigned employees
      process_unassigned_employees(parsed_data[:unassigned_employees] || [])

      # Update summary
      update_summary

      true
    end
  rescue => e
    results[:failures] << {
      type: 'system_error',
      error: e.message,
      backtrace: e.backtrace.first(5)
    }
    false
  end

  private

  def process_departments(departments_data)
    departments_data.each do |department_data|
      begin
        department_name = department_data['name']
        next if department_name.blank?

        # Check if department already exists
        existing_department = Organization.departments.find_by(name: department_name, parent: organization)
        
        if existing_department
          # Department already exists, no action needed
          results[:successes] << {
            type: 'department',
            action: 'exists',
            name: department_name,
            id: existing_department.id
          }
        else
          # Create new department
          department = Organization.departments.create!(
            name: department_name,
            parent: organization,
            type: 'Department'
          )

          results[:successes] << {
            type: 'department',
            action: 'created',
            name: department_name,
            id: department.id
          }
        end

        results[:summary][:successful_creates] += 1
      rescue => e
        results[:failures] << {
          type: 'department',
          action: 'create',
          name: department_data['name'],
          error: e.message,
          row: department_data['row']
        }
        results[:summary][:failed_operations] += 1
      end
    end
  end

  def process_managers(managers_data)
    # Deduplicate managers by email to avoid creating duplicate people
    unique_managers = managers_data.uniq { |m| m['email'] }
    
    unique_managers.each do |manager_data|
      begin
        manager_name = manager_data['name']
        manager_email = manager_data['email']
        next if manager_name.blank? && manager_email.blank?

        # Check if manager already exists
        existing_manager = nil
        if manager_email.present?
          existing_manager = Person.find_by(email: manager_email)
        end
        
        if existing_manager.nil? && manager_name.present?
          name_parts = manager_name.split(' ', 2)
          existing_manager = Person.find_by(
            first_name: name_parts.first,
            last_name: name_parts.last
          )
        end

        if existing_manager
          # Manager already exists, ensure they have teammate relationship
          ensure_teammate_relationship(existing_manager, organization)
          
          results[:successes] << {
            type: 'manager',
            action: 'exists',
            name: existing_manager.display_name,
            email: existing_manager.email,
            id: existing_manager.id
          }
        else
          # Create new manager
          name_parts = manager_name.split(' ', 2)
          manager = Person.create!(
            first_name: name_parts.first,
            last_name: name_parts.last,
            email: manager_email
          )

          # Create teammate relationship
          create_teammate_relationship(manager, organization, 'unassigned_employee')

          results[:successes] << {
            type: 'manager',
            action: 'created',
            name: manager.display_name,
            email: manager.email,
            id: manager.id
          }
        end

        results[:summary][:successful_creates] += 1
      rescue => e
        results[:failures] << {
          type: 'manager',
          action: 'create',
          name: manager_data['name'],
          email: manager_data['email'],
          error: e.message,
          row: manager_data['row']
        }
        results[:summary][:failed_operations] += 1
      end
    end
  end

  def process_unassigned_employees(employees_data)
    employees_data.each do |employee_data|
      begin
        employee_name = employee_data['name']
        employee_email = employee_data['email']
        start_date = employee_data['start_date']
        department_name = employee_data['department']

        # Check if employee already exists
        existing_employee = nil
        if employee_email.present?
          existing_employee = Person.find_by(email: employee_email)
        end
        
        if existing_employee.nil? && employee_name.present?
          name_parts = employee_name.split(' ', 2)
          existing_employee = Person.find_by(
            first_name: name_parts.first,
            last_name: name_parts.last
          )
        end

        if existing_employee
          # Employee already exists, update their information
          update_employee_information(existing_employee, employee_data)
          
          # Ensure teammate relationship exists
          teammate = ensure_teammate_relationship(existing_employee, organization, start_date)
          
          # Create or update employment tenure
          process_employment_tenure(existing_employee, teammate, employee_data)
          
          results[:successes] << {
            type: 'unassigned_employee',
            action: 'updated',
            name: existing_employee.display_name,
            email: existing_employee.email,
            id: existing_employee.id
          }
          
          results[:summary][:successful_updates] += 1
        else
          # Create new employee
          name_parts = employee_name.split(' ', 2)
          employee = Person.create!(
            first_name: name_parts.first,
            last_name: name_parts.last,
            email: employee_email
          )

          # Create teammate relationship as unassigned employee
          teammate = create_teammate_relationship(employee, organization, 'unassigned_employee', start_date)

          # Create employment tenure
          Rails.logger.debug "Processing employment tenure for new employee: #{employee.id}"
          process_employment_tenure(employee, teammate, employee_data)

          results[:successes] << {
            type: 'unassigned_employee',
            action: 'created',
            name: employee.display_name,
            email: employee.email,
            id: employee.id
          }
          
          results[:summary][:successful_creates] += 1
        end

        results[:summary][:total_processed] += 1
      rescue => e
        results[:failures] << {
          type: 'unassigned_employee',
          action: 'create_or_update',
          name: employee_data['name'],
          email: employee_data['email'],
          error: e.message,
          row: employee_data['row']
        }
        results[:summary][:failed_operations] += 1
      end
    end
  end

  def create_teammate_relationship(person, organization, type, start_date = nil)
    teammate = person.teammates.create!(
      organization: organization,
      type: 'CompanyTeammate',
      first_employed_at: start_date || Time.current
    )
    
    teammate
  end

  def ensure_teammate_relationship(person, organization, start_date = nil)
    teammate = person.teammates.find_by(organization: organization)
    
    if teammate.nil?
      teammate = create_teammate_relationship(person, organization, 'unassigned_employee', start_date)
    elsif start_date.present? && teammate.first_employed_at != start_date
      teammate.update!(first_employed_at: start_date)
    end
    
    teammate
  end

      def update_employee_information(employee, employee_data)
        # Update teammate relationship if start date is provided
        if employee_data['start_date'].present?
          teammate = employee.teammates.find_by(organization: organization)
          if teammate
            teammate.update!(first_employed_at: employee_data['start_date'])
          end
        end

        # Update person attributes if they exist
        if employee_data['preferred_name'].present?
          employee.update!(preferred_name: employee_data['preferred_name']) if employee.respond_to?(:preferred_name=)
        end

        # Note: Person model currently only has basic attributes (first_name, last_name, email, etc.)
        # Additional attributes like preferred_name, location, gender, country would need to be added
        # to the Person model or stored elsewhere if needed
      end

  def process_employment_tenure(person, teammate, employee_data)
    begin
      job_title = employee_data['job_title']
      manager_name = employee_data['manager_name']
      start_date = employee_data['start_date']

      # Find or create position type and position
      position = find_or_create_position(job_title)
      
      if position.nil?
        # Position could not be created, record failure
        results[:failures] << {
          type: 'employment_tenure',
          action: 'create',
          person_name: employee_data['name'],
          error: "Position could not be created for job title: '#{job_title}'",
          row: employee_data['row']
        }
        results[:summary][:failed_operations] += 1
        return
      end

      # Find manager teammate if specified
      manager_teammate = find_manager_teammate_by_name(manager_name) if manager_name.present?

      # Check if employment tenure already exists
      existing_tenure = teammate.employment_tenures.find_by(company: organization)
      
      
      if existing_tenure
        # Employment tenure already exists
        results[:successes] << {
          type: 'employment_tenure',
          action: 'exists',
          person_name: person.display_name,
          position_title: existing_tenure.position.title.external_title,
          id: existing_tenure.id
        }
        results[:summary][:successful_creates] += 1
      else
        # Create new employment tenure
        employment_tenure = create_employment_tenure(person, teammate, employee_data)
        
        # Create observable moment for new hire (only if no active tenure existed)
        # Use the bulk_sync_event's creator if available, otherwise skip (bulk operations may not have a user)
        if bulk_sync_event&.creator
          ObservableMoments::CreateNewHireMomentService.call(
            employment_tenure: employment_tenure,
            created_by: bulk_sync_event.creator
          )
        end
        
        results[:successes] << {
          type: 'employment_tenure',
          action: 'created',
          person_name: person.display_name,
          position_title: employment_tenure.position.title.external_title,
          id: employment_tenure.id
        }
        results[:summary][:successful_creates] += 1
      end
    rescue => e
      results[:failures] << {
        type: 'employment_tenure',
        action: 'create',
        person_name: employee_data['name'],
        error: e.message,
        row: employee_data['row']
      }
      results[:summary][:failed_operations] += 1
    end
  end

  def find_or_create_position(job_title)
    return nil if job_title.blank?

    # Find existing title
    title = Title.find_by(external_title: job_title, organization: organization)
    
    if title.nil?
      # Create new title
      position_major_level = PositionMajorLevel.first || PositionMajorLevel.create!(set_name: 'Engineering', major_level: 'Standard')
      title = Title.create!(
        external_title: job_title,
        organization: organization,
        position_major_level: position_major_level
      )
    end

    # Find existing position for this title
    position = Position.find_by(title: title)
    
    if position.nil?
      # Create new position
      position_level = PositionLevel.find_by(position_major_level: title.position_major_level) || 
                      PositionLevel.create!(position_major_level: title.position_major_level, level: '1.0')
      
      position = Position.create!(
        title: title,
        position_level: position_level
      )
    end

    position
  end

  def find_manager_teammate_by_name(manager_name)
    return nil if manager_name.blank?

    # Try to find manager person by name
    name_parts = manager_name.split(' ', 2)
    manager_person = if name_parts.length >= 2
      Person.find_by(
        first_name: name_parts.first,
        last_name: name_parts.last
      )
    else
      # If only one name part, try to find by first name
      Person.find_by(first_name: manager_name)
    end
    
    # Find CompanyTeammate for this person in the organization
    return nil unless manager_person
    
    CompanyTeammate.find_by(organization: organization, person: manager_person)
  end

  def create_employment_tenure(person, teammate, employee_data)
    job_title = employee_data['job_title']
    manager_name = employee_data['manager_name']
    
    # Find or create position
    position = find_or_create_position(job_title)
    if position.nil?
      raise ActiveRecord::RecordInvalid.new(EmploymentTenure.new)
    end
    
    # Find manager teammate if specified
    manager_teammate = find_manager_teammate_by_name(manager_name) if manager_name.present?
    
    EmploymentTenure.create!(
      teammate: teammate,
      company: organization,
      position: position,
      manager_teammate: manager_teammate,
      started_at: employee_data['start_date'] || Time.current
    )
  end

  def update_summary
    results[:summary][:total_processed] = results[:successes].count + results[:failures].count
  end
end
