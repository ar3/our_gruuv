require 'csv'

class AssignmentsAndAbilitiesUploadParser
  include FlexibleNameMatcher

  # Expected headers for the CSV file
  EXPECTED_HEADERS = %w[
    Assignment
    Position(s)
    Team(s)
    Tagline
    Outcomes
    Abilities
    Required Activities
  ].freeze

  attr_reader :file_content, :errors, :parsed_data, :organization

  def initialize(file_content, organization = nil)
    @file_content = file_content
    @organization = organization
    @errors = []
    @parsed_data = {}
  end

  def parse
    unless valid_file_content?
      Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadParser: File content validation failed. Errors: #{@errors.join(', ')}"
      return false
    end
    
    begin
      # Parse CSV content
      csv_data = CSV.parse(file_content, headers: true, encoding: 'UTF-8')
      Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadParser: Parsed CSV with #{csv_data.length} rows"
      
      # Validate headers
      unless validate_headers(csv_data.headers)
        Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadParser: Header validation failed. Errors: #{@errors.join(', ')}"
        return false
      end
      
      # Initialize parsed data
      @parsed_data = {
        assignments: [],
        abilities: [],
        assignment_abilities: [],
        position_assignments: []
      }
      
      # Parse each row
      csv_data.each_with_index do |row, index|
        row_num = index + 2 # +2 because CSV is 1-indexed and we skip header row
        begin
          parse_row(row, row_num)
        rescue => e
          Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadParser: Error parsing row #{row_num}: #{e.message}"
          Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadParser: Row data: #{row.inspect}"
          @errors << "Error parsing row #{row_num}: #{e.message}"
        end
      end
      
      # Deduplicate and filter out blank titles
      @parsed_data[:assignments] = @parsed_data[:assignments]
        .select { |a| a['title'].present? }
        .uniq { |a| a['title'] }
      @parsed_data[:abilities] = @parsed_data[:abilities]
        .select { |a| a['name'].present? }
        .uniq { |a| a['name'] }
      
      Rails.logger.info "❌❌❌ AssignmentsAndAbilitiesUploadParser: Successfully parsed #{@parsed_data[:assignments].length} assignments, #{@parsed_data[:abilities].length} abilities"
      true
    rescue CSV::MalformedCSVError => e
      @errors << "CSV file is malformed: #{e.message}"
      Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadParser: Malformed CSV error: #{e.message}"
      Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadParser: Backtrace: #{e.backtrace.first(5).join("\n")}"
      false
    rescue => e
      @errors << "Error parsing CSV file: #{e.class.name} - #{e.message}"
      Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadParser: Unexpected error: #{e.class.name} - #{e.message}"
      Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadParser: Backtrace: #{e.backtrace.first(10).join("\n")}"
      false
    end
  end

  def preview_actions
    return {} if @parsed_data.empty?

    {
      'assignments' => @parsed_data[:assignments] || [],
      'abilities' => @parsed_data[:abilities] || [],
      'assignment_abilities' => @parsed_data[:assignment_abilities] || [],
      'position_assignments' => @parsed_data[:position_assignments] || []
    }
  end

  def enhanced_preview_actions
    return {} if @parsed_data.empty?

    {
      'assignments' => enhance_assignments_preview(@parsed_data[:assignments] || []),
      'abilities' => enhance_abilities_preview(@parsed_data[:abilities] || []),
      'assignment_abilities' => enhance_assignment_abilities_preview(@parsed_data[:assignment_abilities] || []),
      'position_assignments' => enhance_position_assignments_preview(@parsed_data[:position_assignments] || [])
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
    Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadParser: Validating headers. Found headers: #{headers.inspect}"
    
    # Convert headers to the expected format
    normalized_headers = headers.map { |h| normalize_header(h) }
    Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadParser: Normalized headers: #{normalized_headers.inspect}"
    
    # Check for required headers
    required_headers = ['Assignment']
    missing_headers = required_headers - normalized_headers
    
    if missing_headers.any?
      error_msg = "Missing required headers: #{missing_headers.join(', ')}"
      Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadParser: #{error_msg}"
      Rails.logger.error "❌❌❌ AssignmentsAndAbilitiesUploadParser: Available headers: #{normalized_headers.inspect}"
      @errors << error_msg
      return false
    end
    
    Rails.logger.debug "❌❌❌ AssignmentsAndAbilitiesUploadParser: Header validation passed"
    true
  end

  def normalize_header(header)
    return nil if header.blank?
    
    # Clean up header
    cleaned = header.to_s.strip
    
    # Handle common variations
    cleaned = cleaned.gsub(/[^\w\s()]/, '') # Remove special chars except parentheses
    cleaned = cleaned.squeeze(' ') # Remove extra spaces
    cleaned.strip
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

    # Extract assignment title
    assignment_title = row_hash['Assignment']&.strip
    return if assignment_title.blank?

    # Extract position titles (comma or newline separated)
    position_titles = parse_comma_or_newline_separated(row_hash['Position(s)'] || row_hash['Positions'])

    # Extract team/department names (comma or newline separated) - note: column is "Team(s)" but maps to Departments
    # Pass through all department names (processor will handle multiple values by leaving field untouched)
    department_names = parse_comma_or_newline_separated(row_hash['Team(s)'] || row_hash['Teams'] || row_hash['Department'] || row_hash['Departments'])

    # Extract tagline
    tagline = row_hash['Tagline']&.strip

    # Extract outcomes (multi-line)
    outcomes = parse_multiline(row_hash['Outcomes'] || row_hash['Outcome'])

    # Extract abilities (comma or newline separated)
    ability_names = parse_ability_names(row_hash['Abilities'] || row_hash['Ability'])

    # Extract required activities (multi-line)
    required_activities = parse_multiline(row_hash['Required Activities'] || row_hash['RequiredActivities'] || row_hash['Required Activity'])

    # Create assignment data
    assignment_data = {
      'title' => assignment_title,
      'tagline' => tagline,
      'outcomes' => outcomes,
      'required_activities' => required_activities,
      'department_names' => department_names,
      'row' => row_num
    }
    @parsed_data[:assignments] << assignment_data

    # Create ability data (deduplicated later)
    ability_names.each do |ability_name|
      next if ability_name.blank?
      @parsed_data[:abilities] << {
        'name' => ability_name.strip,
        'row' => row_num
      }
    end

    # Create assignment-ability associations
    ability_names.each do |ability_name|
      next if ability_name.blank?
      @parsed_data[:assignment_abilities] << {
        'assignment_title' => assignment_title,
        'ability_name' => ability_name.strip,
        'row' => row_num
      }
    end

    # Create position-assignment associations
    position_titles.each do |position_title|
      next if position_title.blank?
      @parsed_data[:position_assignments] << {
        'assignment_title' => assignment_title,
        'position_title' => position_title.strip,
        'department_names' => department_names,
        'row' => row_num
      }
    end
  end

  def parse_comma_separated(value)
    return [] if value.blank?
    value.split(',').map(&:strip).reject(&:blank?)
  end

  def parse_multiline(value)
    return [] if value.blank?
    value.split("\n").map(&:strip).reject(&:blank?)
  end

  def parse_comma_or_newline_separated(value)
    return [] if value.blank?
    
    # Split by both comma and newline, then flatten
    # First split by newlines, then split each line by commas
    value.split(/[\n,]+/).map(&:strip).reject(&:blank?)
  end

  def parse_ability_names(value)
    return [] if value.blank?
    
    # Try comma-separated first
    if value.include?(',')
      return value.split(',').map(&:strip).reject(&:blank?)
    end
    
    # Otherwise split by newline
    value.split("\n").map(&:strip).reject(&:blank?)
  end

  def enhance_assignments_preview(assignments)
    return [] if assignments.blank? || organization.blank?
    
    assignments.map do |assignment|
      assignment_title = assignment['title']
      next nil if assignment_title.blank?
      
      # Try to find existing assignment using flexible matching
      existing_assignment = find_with_flexible_matching(
        Assignment,
        :title,
        assignment_title,
        Assignment.where(company: organization)
      )
      
      if existing_assignment
        {
          'title' => assignment_title,
          'tagline' => assignment['tagline'],
          'outcomes' => assignment['outcomes'] || [],
          'outcomes_count' => assignment['outcomes']&.length || 0,
          'required_activities' => assignment['required_activities']&.join("\n"),
          'department_names' => assignment['department_names'] || [],
          'row' => assignment['row'],
          'action' => 'update',
          'existing_id' => existing_assignment.id,
          'existing_title' => existing_assignment.title,
          'will_create' => false
        }
      else
        {
          'title' => assignment_title,
          'tagline' => assignment['tagline'],
          'outcomes' => assignment['outcomes'] || [],
          'outcomes_count' => assignment['outcomes']&.length || 0,
          'required_activities' => assignment['required_activities']&.join("\n"),
          'department_names' => assignment['department_names'] || [],
          'row' => assignment['row'],
          'action' => 'create',
          'existing_id' => nil,
          'existing_title' => nil,
          'will_create' => true
        }
      end
    end.compact
  end

  def enhance_abilities_preview(abilities)
    return [] if abilities.blank? || organization.blank?
    
    abilities.map do |ability|
      ability_name = ability['name']
      next nil if ability_name.blank?
      
      # Try to find existing ability using flexible matching
      existing_ability = find_with_flexible_matching(
        Ability,
        :name,
        ability_name,
        Ability.where(organization: organization)
      )
      
      if existing_ability
        {
          'name' => ability_name,
          'row' => ability['row'],
          'action' => 'update',
          'existing_id' => existing_ability.id,
          'existing_name' => existing_ability.name,
          'will_create' => false
        }
      else
        {
          'name' => ability_name,
          'row' => ability['row'],
          'action' => 'create',
          'existing_id' => nil,
          'existing_name' => nil,
          'will_create' => true
        }
      end
    end.compact
  end

  def enhance_assignment_abilities_preview(assignment_abilities)
    assignment_abilities.map do |aa|
      {
        'assignment_title' => aa['assignment_title'],
        'ability_name' => aa['ability_name'],
        'milestone_level' => 1,
        'row' => aa['row'],
        'action' => 'create'
      }
    end
  end

  def enhance_position_assignments_preview(position_assignments)
    return [] if position_assignments.blank?
    
    # If organization is blank, return basic data without enhancement
    if organization.blank?
      return position_assignments.map do |pa|
        {
          'assignment_title' => pa['assignment_title'],
          'position_title' => pa['position_title'],
          'department_names' => pa['department_names'],
          'row' => pa['row'],
          'action' => 'create',
          'position_type_title' => nil,
          'position_type_id' => nil,
          'position_id' => nil,
          'position_display_name' => nil,
          'will_create_position' => false,
          'seats_count' => 0,
          'seats' => [],
          'will_update_seat_department' => pa['department_names'].present?
        }
      end
    end
    
    position_assignments.map do |pa|
      position_title = pa['position_title']
      next nil if position_title.blank?
      
      # Find position type using flexible matching
      position_type = find_with_flexible_matching(
        PositionType,
        :external_title,
        position_title,
        PositionType.joins(:organization).where(organizations: { id: organization.id })
      )
      
      unless position_type
        {
          'assignment_title' => pa['assignment_title'],
          'position_title' => position_title,
          'department_names' => pa['department_names'],
          'row' => pa['row'],
          'action' => 'create',
          'position_type_title' => nil,
          'position_type_id' => nil,
          'position_id' => nil,
          'position_display_name' => nil,
          'will_create_position' => false,
          'seats_count' => 0,
          'seats' => [],
          'will_update_seat_department' => pa['department_names'].present?
        }
      else
        # Find existing position for this position type
        position = Position.find_by(position_type: position_type)
        will_create_position = position.nil?
        
        # Get all seats for this position type
        seats = Seat.where(position_type: position_type).includes(:department)
        seats_data = seats.map do |seat|
          {
            'id' => seat.id,
            'display_name' => seat.display_name,
            'department_id' => seat.department_id,
            'department_name' => seat.department&.name
          }
        end
        
        {
          'assignment_title' => pa['assignment_title'],
          'position_title' => position_title,
          'department_names' => pa['department_names'],
          'row' => pa['row'],
          'action' => 'create',
          'position_type_title' => position_type.external_title,
          'position_type_id' => position_type.id,
          'position_id' => position&.id,
          'position_display_name' => position ? position.display_name : "#{position_type.external_title} - [Will be created]",
          'will_create_position' => will_create_position,
          'seats_count' => seats.count,
          'seats' => seats_data,
          'will_update_seat_department' => pa['department_names'].present?
        }
      end
    end.compact
  end
end

