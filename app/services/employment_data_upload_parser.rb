require 'roo'
require 'creek'

class EmploymentDataUploadParser
  # Expected headers for the XLSX file
  EXPECTED_HEADERS = {
    person: ['name', 'email'],
    assignment: ['assignment_name', 'assignment_description'],
    assignment_tenure: ['anticipated_energy_percentage', 'assignment_tenure_start_date', 'assignment_tenure_end_date'],
    assignment_check_in: ['manager_private_notes', 'employee_private_notes', 'official_rating', 'check_in_date', 'energy_percentage', 'manager_rating', 'employee_rating', 'employee_personal_alignment']
  }.freeze

  # Header aliases for user-friendly column names
  HEADER_ALIASES = {
    'Employee' => 'name',
    'Assignment Name' => 'assignment_name',
    'Date of Check-In' => 'check_in_date',
    'Most Recent Actual Calorie %' => 'energy_percentage',
    'Personal Alignment' => 'employee_personal_alignment',
    'Anticipated Calories' => 'anticipated_energy_percentage',
    'Manager Rating' => 'manager_rating',
    'Manager Notes' => 'manager_private_notes',
    'Employee Rating' => 'employee_rating',
    'Employee Notes' => 'employee_private_notes',
    'Final Agreed Rating' => 'official_rating'
  }.freeze

  # Rating values that are valid
  VALID_RATINGS = %w[working_to_meet meeting exceeding].freeze

  # URL regex pattern to extract links from assignment names
  URL_REGEX = /\[(https?:\/\/[^\]]+)\]/

  attr_reader :file_content, :errors, :parsed_data

  def initialize(file_content)
    @file_content = file_content
    @errors = []
    @parsed_data = {}
  end

  def parse
    return false unless valid_file_content?
    
    begin
      # Decode base64 content back to binary if needed
      decoded_content = decode_file_content
      
      # Create a temporary file from the content
      temp_file = create_temp_file(decoded_content)
      
      # Use roo for data extraction
      spreadsheet = Roo::Spreadsheet.open(temp_file.path)
      sheet = spreadsheet.sheet(0)
      
      # Use creek for hyperlink detection (optional)
      hyperlinks_map = {}
      begin
        creek_workbook = Creek::Book.new(temp_file.path)
        creek_sheet = creek_workbook.sheets.first
        
        # Extract hyperlinks mapping
        hyperlinks_map = extract_hyperlinks_mapping(creek_workbook, creek_sheet)
      rescue => e
        # If creek fails, continue without hyperlinks (for testing or corrupted files)
        Rails.logger.warn "Creek hyperlink extraction failed: #{e.message}"
      end
      
      # Parse headers
      headers = sheet.row(1)
      unless validate_headers(headers)
        temp_file.close
        temp_file.unlink
        return false
      end
      
      # Initialize parsed data
      @parsed_data = {
        people: [],
        assignments: [],
        assignment_tenures: [],
        assignment_check_ins: [],
        external_references: []
      }
      
      # Start from row 2 (after headers)
      (2..sheet.last_row).each do |row_num|
        row_data = sheet.row(row_num)
        next if row_data.all?(&:blank?) # Skip empty rows
        
        parse_row(row_data, headers, row_num, hyperlinks_map)
      end
      
      temp_file.close
      temp_file.unlink
      true
    rescue => e
      @errors << "Error parsing file: #{e.message}"
      false
    end
  end

  def preview_actions
    return {} if @parsed_data.empty?

    {
      people: @parsed_data[:people] || [],
      assignments: @parsed_data[:assignments] || [],
      assignment_tenures: @parsed_data[:assignment_tenures] || [],
      assignment_check_ins: @parsed_data[:assignment_check_ins] || [],
      external_references: @parsed_data[:external_references] || []
    }
  end

  def enhanced_preview_actions
    return {} if @parsed_data.empty?

    {
      people: enhance_people_preview(@parsed_data[:people] || []),
      assignments: enhance_assignments_preview(@parsed_data[:assignments] || []),
      assignment_tenures: enhance_tenures_preview(@parsed_data[:assignment_tenures] || []),
      assignment_check_ins: enhance_check_ins_preview(@parsed_data[:assignment_check_ins] || []),
      external_references: @parsed_data[:external_references] || []
    }.transform_values { |value| value.is_a?(Array) ? value : [] }
  end

  private

  def valid_file_content?
    if file_content.blank?
      @errors << "File content is required"
      return false
    end
    
    # Check if content is base64 encoded
    if file_content.match?(/^[A-Za-z0-9+\/=]+$/)
      # Decode and check if it looks like XLSX
      begin
        decoded = Base64.decode64(file_content)
        unless decoded.include?('PK') || decoded.include?('xl/')
          @errors << "File does not appear to be a valid XLSX file"
          return false
        end
      rescue ArgumentError
        @errors << "Invalid base64 encoded content"
        return false
      end
    else
      # Basic validation that content looks like XLSX
      unless file_content.include?('PK') || file_content.include?('xl/')
        @errors << "File does not appear to be a valid XLSX file"
        return false
      end
    end
    
    true
  end

  def decode_file_content
    # Check if content looks like base64 (alphanumeric + / + =)
    if file_content.match?(/^[A-Za-z0-9+\/=]+$/)
      # Decode the base64 string
      Base64.decode64(file_content)
    else
      # Assume it's already binary content
      file_content
    end
  end

  def create_temp_file(content)
    temp_file = Tempfile.new(['upload', '.xlsx'])
    temp_file.binmode
    temp_file.write(content)
    temp_file.rewind
    temp_file
  end

  def extract_headers(headers)
    # Convert headers to lowercase for case-insensitive comparison
    header_names = headers.map(&:downcase).map(&:strip).map(&:underscore)
    
    # Check for basic required headers (email and assignment_name)
    basic_headers = ['email', 'assignment_name']
    basic_headers_found = basic_headers.any? { |h| header_names.include?(h) }
    
    unless basic_headers_found
      @errors << "File must contain at least one of these headers: #{basic_headers.join(', ')}"
      return false
    end
    
    true
  end

  def validate_headers(headers)
    # Convert headers to lowercase for case-insensitive comparison
    header_names = headers.map(&:to_s).map(&:downcase).map(&:strip).map(&:underscore)
    
    # Check for basic required headers (email and assignment_name) or their aliases
    basic_headers = ['email', 'assignment_name']
    basic_aliases = ['employee', 'assignment name']
    
    # Check if we have any of the required headers or their aliases
    has_required = basic_headers.any? { |h| header_names.include?(h) } ||
                   basic_aliases.any? { |h| header_names.include?(h) }
    
    unless has_required
      @errors << "File must contain at least one of these headers: #{basic_headers.join(', ')} or their aliases: #{basic_aliases.join(', ')}"
      return false
    end
    
    true
  end

  def parse_data_rows(sheet, headers)
    @parsed_data = {
      people: [],
      assignments: [],
      assignment_tenures: [],
      assignment_check_ins: [],
      external_references: []
    }

          # Start from row 2 (after headers)
      (2..sheet.last_row).each do |row_num|
        row_data = sheet.row(row_num)
        next if row_data.all?(&:blank?) # Skip empty rows
        
        parse_row(row_data, headers, row_num, hyperlinks_map)
      end
  end

  def parse_row(row_data, headers, row_num, hyperlinks_map)
    # Create a hash mapping header names to values, using aliases
    row_hash = {}
    headers.each_with_index do |header, index|
      mapped_header = map_header_alias(header)
      row_hash[mapped_header.downcase] = row_data[index]
    end

    # Parse person data
    if person_data_present?(row_hash)
      parse_person_data(row_hash, row_num)
    end

    # Parse assignment data
    if assignment_data_present?(row_hash)
      assignment = parse_assignment_data(row_hash, row_num)
      if assignment
        @parsed_data[:assignments] << assignment
        
        # Check for hyperlinks in assignment name using creek data or regex fallback
        url = nil
        
        # First try to get URL from creek hyperlinks
        cell_ref = "B#{row_num}"
        url = hyperlinks_map[cell_ref]
        
        # If no hyperlink found, try regex extraction
        if url.nil?
          url = extract_url_from_assignment_name(row_hash['assignment_name'])
        end
        
        # Create external reference if URL was found
        if url
          cleaned_name = strip_html(row_hash['assignment_name'])
          Rails.logger.info "Parser: Creating external reference - original: '#{row_hash['assignment_name']}' -> cleaned: '#{cleaned_name}'"
          @parsed_data[:external_references] << {
            'assignment_name' => cleaned_name,
            'external_url' => url,
            'row' => row_num
          }
        end
      end
    end

    # Parse assignment tenure data
    if tenure_data_present?(row_hash)
      tenure = parse_tenure_data(row_hash, row_num)
      @parsed_data[:assignment_tenures] << tenure if tenure
    end

    # Parse assignment check-in data
    if check_in_data_present?(row_hash)
      check_in = parse_check_in_data(row_hash, row_num)
      @parsed_data[:assignment_check_ins] << check_in if check_in
    end
  end

  def extract_hyperlinks_mapping(creek_workbook, creek_sheet)
    # Extract hyperlinks mapping from creek
    hyperlinks_map = {}
    
    # Get the sheet XML to find hyperlink references
    sheet_xml_file = creek_workbook.instance_variable_get(:@files).find { |f| f.name == 'xl/worksheets/sheet1.xml' }
    return hyperlinks_map unless sheet_xml_file
    
    sheet_content = sheet_xml_file.get_input_stream.read
    
    # Find hyperlinks section
    if sheet_content.include?('<hyperlinks>')
      hyperlinks_start = sheet_content.index('<hyperlinks>')
      hyperlinks_end = sheet_content.index('</hyperlinks>')
      
      if hyperlinks_start && hyperlinks_end
        hyperlinks_section = sheet_content[hyperlinks_start..hyperlinks_end+12]
        
        # Parse each hyperlink reference
        hyperlinks_section.scan(/<hyperlink r:id="([^"]+)" ref="([^"]+)"/).each do |relationship_id, cell_ref|
          # Get the URL from the relationships file
          url = get_hyperlink_url(creek_workbook, relationship_id)
          if url
            hyperlinks_map[cell_ref] = url
          end
        end
      end
    end
    
    hyperlinks_map
  end

  def get_hyperlink_url(creek_workbook, relationship_id)
    # Get the URL from the relationships file
    rels_file = creek_workbook.instance_variable_get(:@files).find { |f| f.name == 'xl/worksheets/_rels/sheet1.xml.rels' }
    return nil unless rels_file
    
    rels_content = rels_file.get_input_stream.read
    
    # Find the relationship with the given ID
    if rels_content.match(/<Relationship Id="#{relationship_id}"[^>]*Target="([^"]+)"/)
      return $1
    end
    
    nil
  end

  def get_row_hyperlinks(creek_sheet, row_num)
    # Get hyperlinks for a specific row from creek
    hyperlinks = {}
    
    creek_sheet.rows.each do |row|
      next unless row['r'] && row['r'].match(/^[A-Z]+\d+$/)
      
      # Extract row number from cell reference (e.g., "B5" -> 5)
      cell_row = row['r'].match(/\d+/)[0].to_i
      next unless cell_row == row_num
      
      # Check if this cell has a hyperlink
      if row['hyperlink']
        hyperlinks[row['r']] = row['hyperlink']
      end
    end
    
    hyperlinks
  end

  def extract_url_from_assignment_with_hyperlinks(assignment_name, hyperlinks_map)
    # Check if this assignment name has a hyperlink
    # We need to find which row this assignment is in to map to the hyperlink
    # For now, let's use the regex fallback
    extract_url_from_assignment_name(assignment_name)
  end

  def person_data_present?(row_hash)
    row_hash['name'].present?
  end

  def assignment_data_present?(row_hash)
    row_hash['assignment_name'].present?
  end

  def tenure_data_present?(row_hash)
    row_hash['anticipated_energy_percentage'].present? ||
    row_hash['assignment_tenure_start_date'].present? ||
    row_hash['assignment_tenure_end_date'].present?
  end

  def check_in_data_present?(row_hash)
    row_hash['check_in_date'].present? ||
    row_hash['energy_percentage'].present? ||
    row_hash['manager_rating'].present? ||
    row_hash['employee_rating'].present? ||
    row_hash['official_rating'].present? ||
    row_hash['manager_private_notes'].present? ||
    row_hash['employee_private_notes'].present? ||
    row_hash['employee_personal_alignment'].present?
  end

  def parse_person_data(row_hash, row_num)
    name = row_hash['name']&.strip
    email = row_hash['email']&.strip&.downcase
    
    # Auto-generate email from name if not provided
    if email.blank? && name.present?
      email = generate_email_from_name(name)
    end

    person_data = {
      'name' => name,
      'email' => email,
      'row' => row_num
    }

    @parsed_data[:people] << person_data
  end

  def parse_assignment_data(row_hash, row_num)
    {
      'assignment_name' => strip_html(row_hash['assignment_name']&.strip),
      'assignment_description' => strip_html(row_hash['assignment_description']&.strip),
      'row' => row_num
    }
  end

  def parse_tenure_data(row_hash, row_num)
    energy_percentage = parse_energy_percentage(row_hash['anticipated_energy_percentage'])
    start_date = parse_date(row_hash['assignment_tenure_start_date'])
    end_date = parse_date(row_hash['assignment_tenure_end_date'])

    {
      'anticipated_energy_percentage' => energy_percentage,
      'assignment_tenure_start_date' => start_date,
      'assignment_tenure_end_date' => end_date,
      'row' => row_num
    }
  end

  def parse_check_in_data(row_hash, row_num)
    check_in_date = parse_date(row_hash['check_in_date'])
    # Default to today if no check-in date is provided
    check_in_date = Date.current if check_in_date.nil?
    
    energy_percentage = parse_energy_percentage(row_hash['energy_percentage'])
    manager_rating = parse_rating(row_hash['manager_rating'])
    employee_rating = parse_rating(row_hash['employee_rating'])
    official_rating = parse_rating(row_hash['official_rating'])
    employee_personal_alignment = parse_personal_alignment(row_hash['employee_personal_alignment'])

    {
      'check_in_date' => check_in_date,
      'energy_percentage' => energy_percentage,
      'manager_rating' => manager_rating,
      'employee_rating' => employee_rating,
      'official_rating' => official_rating,
      'manager_private_notes' => row_hash['manager_private_notes']&.strip,
      'employee_private_notes' => row_hash['employee_private_notes']&.strip,
      'employee_personal_alignment' => employee_personal_alignment,
      'row' => row_num
    }
  end

  def extract_url_from_assignment_name(assignment_name)
    return nil if assignment_name.blank?
    
    match = assignment_name.match(URL_REGEX)
    match ? match[1] : nil
  end

  def map_header_alias(header)
    HEADER_ALIASES[header] || header
  end

  def generate_email_from_name(name)
    return '@careerplug.com' if name.blank?
    "#{name}@careerplug.com"
  end

  def enhance_people_preview(people_data)
    return [] if people_data.blank?
    
    people_data.map do |person_data|
      # Try to find existing person by email or name
      existing_person = nil
      action = 'create'
      
      if person_data['email'].present?
        existing_person = Person.find_by_email_insensitive(person_data['email'])
      end
      
      if existing_person.nil? && person_data['name'].present?
        name_parts = person_data['name'].split(' ', 2)
        existing_person = Person.find_by(
          first_name: name_parts.first,
          last_name: name_parts.last
        )
      end
      
      if existing_person
        action = 'update'
        person_data.merge(
          'action' => action,
          'existing_id' => existing_person.id,
          'existing_name' => existing_person.display_name,
          'will_create' => false
        )
      else
        person_data.merge(
          'action' => action,
          'existing_id' => nil,
          'existing_name' => nil,
          'will_create' => true
        )
      end
    end
  end

  def enhance_assignments_preview(assignments_data)
    return [] if assignments_data.blank?
    
    assignments_data.map do |assignment_data|
      # Try to find existing assignment by name
      existing_assignment = nil
      action = 'create'
      
      if assignment_data['assignment_name'].present?
        cleaned_name = strip_html(assignment_data['assignment_name'])
        Rails.logger.info "Parser: Looking up assignment by name: '#{assignment_data['assignment_name']}' -> cleaned: '#{cleaned_name}'"
        existing_assignment = Assignment.find_by(title: cleaned_name)
      end
      
      if existing_assignment
        action = 'update'
        assignment_data.merge(
          'action' => action,
          'existing_id' => existing_assignment.id,
          'existing_title' => existing_assignment.title,
          'will_create' => false
        )
      else
        assignment_data.merge(
          'action' => action,
          'existing_id' => nil,
          'existing_title' => nil,
          'will_create' => true
        )
      end
    end
  end

  def enhance_tenures_preview(tenures_data)
    return [] if tenures_data.blank?
    
    tenures_data.map do |tenure_data|
      # For tenures, we need to reference the person and assignment
      person_data = find_person_by_row(tenure_data['row'])
      assignment_data = find_assignment_by_row(tenure_data['row'])
      
      # Try to find existing tenure
      existing_tenure = nil
      action = 'create'
      
      if person_data && assignment_data
        # Find the person and assignment objects
        person = find_existing_person(person_data)
        assignment = find_existing_assignment(assignment_data)
        
        if person && assignment
          existing_tenure = AssignmentTenure.most_recent_for(person, assignment)
        end
      end
      
      if existing_tenure
        action = 'update'
        tenure_data.merge(
          'action' => action,
          'existing_id' => existing_tenure.id,
          'existing_tenure' => existing_tenure,
          'will_create' => false,
          'person_reference' => person_data,
          'assignment_reference' => assignment_data
        )
      else
        tenure_data.merge(
          'action' => action,
          'existing_id' => nil,
          'existing_tenure' => nil,
          'will_create' => true,
          'person_reference' => person_data,
          'assignment_reference' => assignment_data
        )
      end
    end
  end

  def enhance_check_ins_preview(check_ins_data)
    return [] if check_ins_data.blank?
    
    check_ins_data.map do |check_in_data|
      # For check-ins, we need to reference the person and assignment
      person_data = find_person_by_row(check_in_data['row'])
      assignment_data = find_assignment_by_row(check_in_data['row'])
      
      # Try to find existing check-in
      existing_check_in = nil
      action = 'create'
      
      if person_data && assignment_data
        # Find the person and assignment objects
        person = find_existing_person(person_data)
        assignment = find_existing_assignment(assignment_data)
        
        if person && assignment
          # Look for existing check-in by date and assignment
          if check_in_data['check_in_date'].present?
            existing_check_in = AssignmentCheckIn.find_by(
              assignment_id: assignment.id,
              check_in_started_on: check_in_data['check_in_date']
            )
          end
        end
      end
      
      if existing_check_in
        action = 'update'
        check_in_data.merge(
          'action' => action,
          'existing_id' => existing_check_in.id,
          'existing_check_in' => existing_check_in,
          'will_create' => false,
          'person_reference' => person_data,
          'assignment_reference' => assignment_data
        )
      else
        check_in_data.merge(
          'action' => action,
          'existing_id' => nil,
          'existing_check_in' => nil,
          'will_create' => true,
          'person_reference' => person_data,
          'assignment_reference' => assignment_data
        )
      end
    end
  end

  def find_person_by_row(row_num)
    @parsed_data[:people].find { |p| p['row'] == row_num }
  end

  def find_assignment_by_row(row_num)
    @parsed_data[:assignments].find { |a| a['row'] == row_num }
  end

  def find_existing_person(person_data)
    if person_data['email'].present?
      Person.find_by_email_insensitive(person_data['email'])
    elsif person_data['name'].present?
      name_parts = person_data['name'].split(' ', 2)
      Person.find_by(
        first_name: name_parts.first,
        last_name: name_parts.last
      )
    end
  end

  def find_existing_assignment(assignment_data)
    if assignment_data['assignment_name'].present?
      cleaned_name = strip_html(assignment_data['assignment_name'])
      Rails.logger.info "Parser: find_existing_assignment - '#{assignment_data['assignment_name']}' -> cleaned: '#{cleaned_name}'"
      Assignment.find_by(title: cleaned_name)
    end
  end

  def parse_energy_percentage(value)
    return nil if value.blank?
    
    # Handle numeric values
    if value.is_a?(Numeric)
      percentage = value.to_i
      return percentage if percentage >= 0 && percentage <= 100
      return nil
    end
    
    # Handle string values
    string_value = value.to_s.strip.gsub('%', '')
    return nil unless string_value.match?(/^\d+$/)
    
    percentage = string_value.to_i
    return nil if percentage < 0 || percentage > 100
    
    percentage
  rescue
    nil
  end

  def parse_date(value)
    return nil if value.blank?
    
    # Handle various date formats
    if value.is_a?(Date)
      value
    elsif value.is_a?(Time) || value.is_a?(DateTime)
      value.to_date
    elsif value.is_a?(Numeric)
      # Excel stores dates as numbers
      Date.new(1900, 1, 1) + value.to_i - 2
    else
      begin
        Date.parse(value.to_s)
      rescue
        nil
      end
    end
  end

  def parse_rating(value)
    return nil if value.blank?
    
    rating = value.to_s.strip.downcase
    VALID_RATINGS.include?(rating) ? rating : nil
  end

  def parse_personal_alignment(value)
    return nil if value.blank?
    
    alignment = value.to_s.strip.downcase
    original_value = value.to_s.strip
    
    # Try exact match with enum values first
    valid_alignments = %w[love like neutral prefer_not only_if_necessary]
    return alignment if valid_alignments.include?(alignment)
    
    # Map common variations to enum values
    case alignment
    when /^love/
      'love'
    when /^like/
      'like'
    when /^neutral/
      'neutral'
    when /^prefer\s*not/
      'prefer_not'
    when /^don'?t\s*want/
      'prefer_not'
    when /^only\s*if\s*necessary/
      'only_if_necessary'
    when /^if\s*necessary/
      'only_if_necessary'
    else
      # If no enum match, return the original value (preserve case)
      original_value
    end
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
