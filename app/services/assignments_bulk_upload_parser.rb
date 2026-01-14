require 'csv'

class AssignmentsBulkUploadParser
  include FlexibleNameMatcher

  # Expected headers for the CSV file (matching download format)
  EXPECTED_HEADERS = %w[
    Assignment ID
    Title
    Tagline
    Department
    Positions
    Milestones
    Outcomes
    Required Activities
    Handbook
    Version
    Changes Count
    Public URL
    Created At
    Updated At
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
      Rails.logger.error "❌❌❌ AssignmentsBulkUploadParser: File content validation failed. Errors: #{@errors.join(', ')}"
      return false
    end
    
    begin
      # Parse CSV content
      csv_data = CSV.parse(file_content, headers: true, encoding: 'UTF-8')
      Rails.logger.debug "❌❌❌ AssignmentsBulkUploadParser: Parsed CSV with #{csv_data.length} rows"
      
      # Validate headers
      unless validate_headers(csv_data.headers)
        Rails.logger.error "❌❌❌ AssignmentsBulkUploadParser: Header validation failed. Errors: #{@errors.join(', ')}"
        return false
      end
      
      # Initialize parsed data
      @parsed_data = {
        assignments: []
      }
      
      # Parse each row
      csv_data.each_with_index do |row, index|
        row_num = index + 2 # +2 because CSV is 1-indexed and we skip header row
        begin
          parse_row(row, row_num)
        rescue => e
          Rails.logger.error "❌❌❌ AssignmentsBulkUploadParser: Error parsing row #{row_num}: #{e.message}"
          Rails.logger.error "❌❌❌ AssignmentsBulkUploadParser: Row data: #{row.inspect}"
          @errors << "Error parsing row #{row_num}: #{e.message}"
        end
      end
      
      # Filter out blank assignments
      @parsed_data[:assignments] = @parsed_data[:assignments]
        .select { |a| a['assignment_id'].present? || a['title'].present? }
      
      Rails.logger.info "❌❌❌ AssignmentsBulkUploadParser: Successfully parsed #{@parsed_data[:assignments].length} assignments"
      true
    rescue CSV::MalformedCSVError => e
      @errors << "CSV file is malformed: #{e.message}"
      Rails.logger.error "❌❌❌ AssignmentsBulkUploadParser: Malformed CSV error: #{e.message}"
      false
    rescue => e
      @errors << "Error parsing CSV file: #{e.class.name} - #{e.message}"
      Rails.logger.error "❌❌❌ AssignmentsBulkUploadParser: Unexpected error: #{e.class.name} - #{e.message}"
      false
    end
  end

  def preview_actions
    return {} if @parsed_data.empty?

    {
      'assignments' => @parsed_data[:assignments] || []
    }
  end

  def enhanced_preview_actions
    return {} if @parsed_data.empty?

    {
      'assignments' => enhance_assignments_preview(@parsed_data[:assignments] || [])
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
    Rails.logger.debug "❌❌❌ AssignmentsBulkUploadParser: Validating headers. Found headers: #{headers.inspect}"
    
    # Convert headers to the expected format
    normalized_headers = headers.map { |h| normalize_header(h) }
    Rails.logger.debug "❌❌❌ AssignmentsBulkUploadParser: Normalized headers: #{normalized_headers.inspect}"
    
    # Check for required headers (at minimum, we need Assignment ID or Title)
    required_headers = ['Assignment ID', 'Title']
    missing_headers = required_headers - normalized_headers
    
    if missing_headers.length == required_headers.length
      error_msg = "Missing required headers: Need at least 'Assignment ID' or 'Title'"
      Rails.logger.error "❌❌❌ AssignmentsBulkUploadParser: #{error_msg}"
      @errors << error_msg
      return false
    end
    
    Rails.logger.debug "❌❌❌ AssignmentsBulkUploadParser: Header validation passed"
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

    # Extract assignment ID (primary) or title (fallback)
    assignment_id = row_hash['Assignment ID']&.strip
    assignment_title = row_hash['Title']&.strip
    
    # Need at least one identifier
    return if assignment_id.blank? && assignment_title.blank?

    # Extract other fields
    tagline = row_hash['Tagline']&.strip
    department = row_hash['Department']&.strip
    positions_text = row_hash['Positions']&.strip
    milestones_text = row_hash['Milestones']&.strip
    outcomes_text = row_hash['Outcomes']&.strip
    required_activities = row_hash['Required Activities'] || row_hash['RequiredActivities'] || row_hash['Required Activity']
    handbook = row_hash['Handbook']&.strip
    version = row_hash['Version']&.strip

    # Parse positions: "External Title - Level (assignment_type, min%-max%)" format
    positions = parse_positions(positions_text)

    # Parse milestones: "Ability Name - Milestone X" format
    milestones = parse_milestones(milestones_text)

    # Parse outcomes: newline-separated
    outcomes = parse_multiline(outcomes_text)

    # Create assignment data
    assignment_data = {
      'assignment_id' => assignment_id,
      'title' => assignment_title,
      'tagline' => tagline,
      'department' => department,
      'positions' => positions,
      'milestones' => milestones,
      'outcomes' => outcomes,
      'required_activities' => required_activities,
      'handbook' => handbook,
      'version' => version,
      'row' => row_num
    }
    @parsed_data[:assignments] << assignment_data
  end

  def parse_positions(positions_text)
    return [] if positions_text.blank?
    
    positions_text.split("\n").map(&:strip).reject(&:blank?).map do |position_str|
      # Format: "External Title - Level (assignment_type, min%-max%)"
      # Examples:
      #   "Senior Engineer - 2.0 (required, 20%-40%)"
      #   "Junior Designer - 1.0 (suggested, 10%+)"
      #   "Manager - 3.0 (required, up to 50%)"
      
      match = position_str.match(/\A(.+?)\s*-\s*([\d.]+)\s*\(([^,]+)(?:,\s*(.+?))?\)\z/)
      
      if match
        external_title = match[1].strip
        level = match[2].strip
        assignment_type = match[3].strip
        energy_part = match[4]&.strip
        
        # Parse energy range
        min_energy = nil
        max_energy = nil
        
        if energy_part.present?
          if (m = energy_part.match(/\A(\d+)%-(\d+)%\z/))
            # Format: "20%-40%"
            min_energy = m[1].to_i
            max_energy = m[2].to_i
          elsif (m = energy_part.match(/\A(\d+)%\+\z/))
            # Format: "10%+"
            min_energy = m[1].to_i
          elsif (m = energy_part.match(/\Aup to (\d+)%\z/i))
            # Format: "up to 50%"
            max_energy = m[1].to_i
          end
        end
        
        {
          'external_title' => external_title,
          'level' => level,
          'assignment_type' => assignment_type,
          'min_estimated_energy' => min_energy,
          'max_estimated_energy' => max_energy
        }
      else
        # If format doesn't match, log warning but don't fail
        Rails.logger.warn "❌❌❌ AssignmentsBulkUploadParser: Could not parse position format: #{position_str}"
        nil
      end
    end.compact
  end

  def parse_milestones(milestones_text)
    return [] if milestones_text.blank?
    
    milestones_text.split("\n").map(&:strip).reject(&:blank?).map do |milestone_str|
      # Format: "Ability Name - Milestone X"
      # Example: "Communication - Milestone 3"
      
      match = milestone_str.match(/\A(.+?)\s*-\s*Milestone\s+(\d+)\z/i)
      
      if match
        ability_name = match[1].strip
        milestone_level = match[2].to_i
        
        # Validate milestone level
        if milestone_level < 1 || milestone_level > 5
          Rails.logger.warn "❌❌❌ AssignmentsBulkUploadParser: Invalid milestone level #{milestone_level} in: #{milestone_str}"
          nil
        else
          {
            'ability_name' => ability_name,
            'milestone_level' => milestone_level
          }
        end
      else
        Rails.logger.warn "❌❌❌ AssignmentsBulkUploadParser: Could not parse milestone format: #{milestone_str}"
        nil
      end
    end.compact
  end

  def parse_multiline(value)
    return [] if value.blank?
    value.split("\n").map(&:strip).reject(&:blank?)
  end

  def enhance_assignments_preview(assignments)
    return [] if assignments.blank? || organization.blank?
    
    assignments.map do |assignment|
      assignment_id = assignment['assignment_id']
      assignment_title = assignment['title']
      
      # Find existing assignment by ID first, then by title
      existing_assignment = if assignment_id.present?
        Assignment.find_by(id: assignment_id, company: organization.self_and_descendants)
      end
      
      existing_assignment ||= if assignment_title.present?
        find_with_flexible_matching(
          Assignment,
          :title,
          assignment_title,
          Assignment.where(company: organization.self_and_descendants)
        )
      end
      
      if existing_assignment
        {
          'assignment_id' => assignment_id,
          'title' => assignment_title,
          'tagline' => assignment['tagline'],
          'department' => assignment['department'],
          'positions' => assignment['positions'] || [],
          'milestones' => assignment['milestones'] || [],
          'outcomes' => assignment['outcomes'] || [],
          'required_activities' => assignment['required_activities'],
          'handbook' => assignment['handbook'],
          'version' => assignment['version'],
          'row' => assignment['row'],
          'action' => 'update',
          'existing_id' => existing_assignment.id,
          'existing_title' => existing_assignment.title,
          'will_create' => false
        }
      else
        {
          'assignment_id' => assignment_id,
          'title' => assignment_title,
          'tagline' => assignment['tagline'],
          'department' => assignment['department'],
          'positions' => assignment['positions'] || [],
          'milestones' => assignment['milestones'] || [],
          'outcomes' => assignment['outcomes'] || [],
          'required_activities' => assignment['required_activities'],
          'handbook' => assignment['handbook'],
          'version' => assignment['version'],
          'row' => assignment['row'],
          'action' => 'create',
          'existing_id' => nil,
          'existing_title' => nil,
          'will_create' => true
        }
      end
    end.compact
  end
end
