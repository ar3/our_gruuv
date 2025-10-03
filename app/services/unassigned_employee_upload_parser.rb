require 'csv'

class UnassignedEmployeeUploadParser
  # Expected headers for the CSV file
  EXPECTED_HEADERS = %w[
    Name
    Preferred Name
    Email
    Start Date
    Location
    Gender
    Department
    Employment Type
    Manager
    Country
    Manager Email
    Job Title
    Job Title Level
  ].freeze

  # Header aliases for user-friendly column names
  HEADER_ALIASES = {
    'Full Name' => 'Name',
    'Preferred Name' => 'Preferred Name',
    'Email Address' => 'Email',
    'Start Date' => 'Start Date',
    'Work Location' => 'Location',
    'Gender' => 'Gender',
    'Department' => 'Department',
    'Employment Type' => 'Employment Type',
    'Manager Name' => 'Manager',
    'Country' => 'Country',
    'Manager Email' => 'Manager Email',
    'Job Title' => 'Job Title',
    'Job Title Level' => 'Job Title Level'
  }.freeze

  # Valid employment types
  VALID_EMPLOYMENT_TYPES = %w[full_time part_time contract intern].freeze

  # Valid genders
  VALID_GENDERS = %w[male female non_binary other prefer_not_to_say].freeze

  # Valid job title levels
  VALID_JOB_TITLE_LEVELS = %w[entry mid senior lead director executive].freeze

  attr_reader :file_content, :errors, :parsed_data

  def initialize(file_content)
    @file_content = file_content
    @errors = []
    @parsed_data = {}
  end

  def parse
    return false unless valid_file_content?
    
    begin
      # Parse CSV content
      csv_data = CSV.parse(file_content, headers: true, encoding: 'UTF-8')
      
      # Validate headers
      unless validate_headers(csv_data.headers)
        return false
      end
      
      # Initialize parsed data
      @parsed_data = {
        unassigned_employees: [],
        departments: [],
        managers: []
      }
      
      # Parse each row
      csv_data.each_with_index do |row, index|
        row_num = index + 2 # +2 because CSV is 1-indexed and we skip header row
        parse_row(row, row_num)
      end

      # Deduplicate departments and managers
      @parsed_data[:departments] = @parsed_data[:departments].uniq { |d| d['name'] }
      @parsed_data[:managers] = @parsed_data[:managers].uniq { |m| m['name'] }
      
      true
    rescue => e
      @errors << "Error parsing CSV file: #{e.message}"
      false
    end
  end

  def preview_actions
    return {} if @parsed_data.empty?

    {
      unassigned_employees: @parsed_data[:unassigned_employees] || [],
      departments: @parsed_data[:departments] || [],
      managers: @parsed_data[:managers] || []
    }
  end

  def enhanced_preview_actions
    return {} if @parsed_data.empty?

    {
      unassigned_employees: enhance_unassigned_employees_preview(@parsed_data[:unassigned_employees] || []),
      departments: enhance_departments_preview(@parsed_data[:departments] || []),
      managers: enhance_managers_preview(@parsed_data[:managers] || [])
    }
  end

  private

  def valid_file_content?
    if file_content.blank?
      @errors << "File content is required"
      return false
    end
    
    # Check if content looks like CSV
    unless file_content.include?(',') || file_content.include?("\n")
      @errors << "File does not appear to be a valid CSV file"
      return false
    end
    
    true
  end

  def validate_headers(headers)
    # Convert headers to the expected format
    normalized_headers = headers.map { |h| normalize_header(h) }
    
    # Check for required headers
    required_headers = ['Name', 'Email']
    missing_headers = required_headers - normalized_headers
    
    unless missing_headers.empty?
      @errors << "Missing required headers: #{missing_headers.join(', ')}"
      return false
    end
    
    # Check for unexpected headers
    unexpected_headers = normalized_headers - EXPECTED_HEADERS
    if unexpected_headers.any?
      Rails.logger.warn "Unexpected headers found: #{unexpected_headers.join(', ')}"
    end
    
    true
  end

  def normalize_header(header)
    # Clean up header and check for aliases
    cleaned_header = header.to_s.strip
    HEADER_ALIASES[cleaned_header] || cleaned_header
  end

  def parse_row(row, row_num)
    # Create a hash mapping header names to values
    row_hash = {}
    row.each do |header, value|
      normalized_header = normalize_header(header)
      row_hash[normalized_header] = value&.strip
    end

    # Skip empty rows
    return if row_hash.values.all?(&:blank?)

    # Parse unassigned employee data
    if unassigned_employee_data_present?(row_hash)
      employee_data = parse_unassigned_employee_data(row_hash, row_num)
      @parsed_data[:unassigned_employees] << employee_data if employee_data
    end

    # Parse department data
    if department_data_present?(row_hash)
      department_data = parse_department_data(row_hash, row_num)
      @parsed_data[:departments] << department_data if department_data
    end

    # Parse manager data
    if manager_data_present?(row_hash)
      manager_data = parse_manager_data(row_hash, row_num)
      @parsed_data[:managers] << manager_data if manager_data
    end
  end

  def unassigned_employee_data_present?(row_hash)
    row_hash['Name'].present? || row_hash['Email'].present?
  end

  def department_data_present?(row_hash)
    row_hash['Department'].present?
  end

  def manager_data_present?(row_hash)
    row_hash['Manager'].present? || row_hash['Manager Email'].present?
  end

  def parse_unassigned_employee_data(row_hash, row_num)
    name = row_hash['Name']&.strip
    preferred_name = row_hash['Preferred Name']&.strip
    email = row_hash['Email']&.strip&.downcase
    start_date = parse_date(row_hash['Start Date'])
    location = row_hash['Location']&.strip
    gender = parse_gender(row_hash['Gender'])
    department = row_hash['Department']&.strip
    employment_type = parse_employment_type(row_hash['Employment Type'])
    manager_name = row_hash['Manager']&.strip
    country = row_hash['Country']&.strip
    manager_email = row_hash['Manager Email']&.strip&.downcase
    job_title = row_hash['Job Title']&.strip
    job_title_level = parse_job_title_level(row_hash['Job Title Level'])

    # Validate required fields
    if name.blank? && email.blank?
      @errors << "Row #{row_num}: Either Name or Email is required"
      return nil
    end

    # Auto-generate email from name if not provided
    if email.blank? && name.present?
      email = generate_email_from_name(name)
    end

    # Auto-generate name from email if not provided
    if name.blank? && email.present?
      name = generate_name_from_email(email)
    end

    {
      'name' => name,
      'preferred_name' => preferred_name,
      'email' => email,
      'start_date' => start_date,
      'location' => location,
      'gender' => gender,
      'department' => department,
      'employment_type' => employment_type,
      'manager_name' => manager_name,
      'country' => country,
      'manager_email' => manager_email,
      'job_title' => job_title,
      'job_title_level' => job_title_level,
      'row' => row_num
    }
  end

  def parse_department_data(row_hash, row_num)
    department_name = row_hash['Department']&.strip
    
    return nil if department_name.blank?

    {
      'name' => department_name,
      'row' => row_num
    }
  end

  def parse_manager_data(row_hash, row_num)
    manager_name = row_hash['Manager']&.strip
    manager_email = row_hash['Manager Email']&.strip&.downcase

    return nil if manager_name.blank? && manager_email.blank?

    # Auto-generate email from name if not provided
    if manager_email.blank? && manager_name.present?
      manager_email = generate_email_from_name(manager_name)
    end

    # Auto-generate name from email if not provided
    if manager_name.blank? && manager_email.present?
      manager_name = generate_name_from_email(manager_email)
    end

    {
      'name' => manager_name,
      'email' => manager_email,
      'row' => row_num
    }
  end

  def enhance_unassigned_employees_preview(employees_data)
    return [] if employees_data.blank?
    
    employees_data.map do |employee_data|
      # Try to find existing person by email or name
      existing_person = nil
      action = 'create'
      
      if employee_data['email'].present?
        existing_person = Person.find_by(email: employee_data['email'])
      end
      
      if existing_person.nil? && employee_data['name'].present?
        name_parts = employee_data['name'].split(' ', 2)
        existing_person = Person.find_by(
          first_name: name_parts.first,
          last_name: name_parts.last
        )
      end
      
      if existing_person
        action = 'update'
        employee_data.merge(
          'action' => action,
          'existing_id' => existing_person.id,
          'existing_name' => existing_person.display_name,
          'will_create' => false
        )
      else
        employee_data.merge(
          'action' => action,
          'existing_id' => nil,
          'existing_name' => nil,
          'will_create' => true
        )
      end
    end
  end

  def enhance_departments_preview(departments_data)
    return [] if departments_data.blank?
    
    departments_data.map do |department_data|
      # Try to find existing department by name
      existing_department = nil
      action = 'create'
      
      if department_data['name'].present?
        existing_department = Organization.departments.find_by(name: department_data['name'])
      end
      
      if existing_department
        action = 'update'
        department_data.merge(
          'action' => action,
          'existing_id' => existing_department.id,
          'existing_name' => existing_department.name,
          'will_create' => false
        )
      else
        department_data.merge(
          'action' => action,
          'existing_id' => nil,
          'existing_name' => nil,
          'will_create' => true
        )
      end
    end
  end

  def enhance_managers_preview(managers_data)
    return [] if managers_data.blank?
    
    managers_data.map do |manager_data|
      # Try to find existing person by email or name
      existing_manager = nil
      action = 'create'
      
      if manager_data['email'].present?
        existing_manager = Person.find_by(email: manager_data['email'])
      end
      
      if existing_manager.nil? && manager_data['name'].present?
        name_parts = manager_data['name'].split(' ', 2)
        existing_manager = Person.find_by(
          first_name: name_parts.first,
          last_name: name_parts.last
        )
      end
      
      if existing_manager
        action = 'update'
        manager_data.merge(
          'action' => action,
          'existing_id' => existing_manager.id,
          'existing_name' => existing_manager.display_name,
          'will_create' => false
        )
      else
        manager_data.merge(
          'action' => action,
          'existing_id' => nil,
          'existing_name' => nil,
          'will_create' => true
        )
      end
    end
  end

  def parse_date(value)
    return nil if value.blank?
    
    begin
      # Try to parse as-is first
      Date.parse(value.to_s)
    rescue
      begin
        # Try common formats
        if value.to_s.match?(/^\d{1,2}\/\d{1,2}\/\d{4}$/)
          Date.strptime(value.to_s, '%m/%d/%Y')
        elsif value.to_s.match?(/^\d{4}-\d{1,2}-\d{1,2}$/)
          Date.strptime(value.to_s, '%Y-%m-%d')
        else
          nil
        end
      rescue
        nil
      end
    end
  end

  def parse_gender(value)
    return nil if value.blank?
    
    gender = value.to_s.strip.downcase
    VALID_GENDERS.include?(gender) ? gender : nil
  end

  def parse_employment_type(value)
    return nil if value.blank?
    
    employment_type = value.to_s.strip.downcase.gsub(' ', '_')
    VALID_EMPLOYMENT_TYPES.include?(employment_type) ? employment_type : nil
  end

  def parse_job_title_level(value)
    return nil if value.blank?
    
    level = value.to_s.strip.downcase
    VALID_JOB_TITLE_LEVELS.include?(level) ? level : nil
  end

  def generate_email_from_name(name)
    return nil if name.blank?
    
    # Simple email generation - can be customized based on domain
    name_parts = name.split(' ')
    if name_parts.length >= 2
      "#{name_parts.first.downcase}.#{name_parts.last.downcase}@company.com"
    else
      "#{name.downcase.gsub(' ', '.')}@company.com"
    end
  end

  def generate_name_from_email(email)
    return nil if email.blank?
    
    # Extract name from email address
    local_part = email.split('@').first
    name_parts = local_part.split('.')
    
    if name_parts.length >= 2
      "#{name_parts.first.titleize} #{name_parts.last.titleize}"
    else
      name_parts.first.titleize
    end
  end
end
