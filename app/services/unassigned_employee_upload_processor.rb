class UnassignedEmployeeUploadProcessor
  attr_reader :upload_event, :organization, :parser, :results

  def initialize(upload_event, organization)
    @upload_event = upload_event
    @organization = organization
    @parser = UnassignedEmployeeUploadParser.new(upload_event.file_content)
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
          ensure_teammate_relationship(existing_employee, organization, start_date)
          
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
          create_teammate_relationship(employee, organization, 'unassigned_employee', start_date)

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

  def update_summary
    results[:summary][:total_processed] = results[:successes].count + results[:failures].count
  end
end
