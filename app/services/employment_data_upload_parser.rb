class EmploymentDataUploadParser
  require 'roo'

  # Expected headers for the XLSX file
  EXPECTED_HEADERS = {
    person: ['name', 'email'],
    assignment: ['assignment_name', 'assignment_description'],
    assignment_tenure: ['anticipated_energy_percentage', 'assignment_tenure_start_date', 'assignment_tenure_end_date'],
    assignment_check_in: ['manager_private_notes', 'employee_private_notes', 'official_rating', 'check_in_date', 'energy_percentage', 'manager_rating', 'employee_rating']
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
      # Create a temporary file from the content
      temp_file = create_temp_file
      
      # Parse the XLSX file
      spreadsheet = Roo::Spreadsheet.open(temp_file.path)
      sheet = spreadsheet.sheet(0)
      
      # Extract headers and validate
      headers = extract_headers(sheet)
      return false unless validate_headers(headers)
      
      # Parse data rows
      parse_data_rows(sheet, headers)
      
      # Clean up temp file
      temp_file.close
      temp_file.unlink
      
      @errors.empty?
    rescue => e
      @errors << "Failed to parse XLSX file: #{e.message}"
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

  private

  def valid_file_content?
    if file_content.blank?
      @errors << "File content is required"
      return false
    end
    
    # Basic validation that content looks like XLSX
    unless file_content.include?('PK') || file_content.include?('xl/')
      @errors << "File does not appear to be a valid XLSX file"
      return false
    end
    
    true
  end

  def create_temp_file
    temp_file = Tempfile.new(['upload', '.xlsx'])
    temp_file.binmode
    temp_file.write(file_content)
    temp_file.rewind
    temp_file
  end

  def extract_headers(sheet)
    sheet.row(1).compact.map(&:to_s).map(&:strip)
  end

  def validate_headers(headers)
    # Convert headers to lowercase for case-insensitive comparison
    header_names = headers.map(&:downcase).map(&:strip).map(&:underscore)
    
    # Check if we have at least the basic required headers
    basic_headers = ['email', 'assignment_name']
    missing_basic = basic_headers.reject { |h| header_names.include?(h) }
    
    if missing_basic.any?
      @errors << "Missing basic required headers: #{missing_basic.join(', ')}"
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
      
      parse_row(row_data, headers, row_num)
    end
  end

  def parse_row(row_data, headers, row_num)
    # Create a hash mapping header names to values
    row_hash = {}
    headers.each_with_index do |header, index|
      row_hash[header.downcase] = row_data[index]
    end

    # Parse person data
    if person_data_present?(row_hash)
      person = parse_person_data(row_hash, row_num)
      @parsed_data[:people] << person if person
    end

    # Parse assignment data
    if assignment_data_present?(row_hash)
      assignment = parse_assignment_data(row_hash, row_num)
      if assignment
        @parsed_data[:assignments] << assignment
        
        # Extract URL from assignment name if present
        if url = extract_url_from_assignment_name(row_hash['assignment_name'])
          @parsed_data[:external_references] << {
            assignment_name: row_hash['assignment_name'],
            url: url,
            row: row_num
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

  def person_data_present?(row_hash)
    row_hash['name'].present? || row_hash['email'].present?
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
    row_hash['manager_private_notes'].present? ||
    row_hash['employee_private_notes'].present? ||
    row_hash['official_rating'].present?
  end

  def parse_person_data(row_hash, row_num)
    name_parts = row_hash['name']&.strip&.split(' ', 2)
    person_data = {
      name: row_hash['name']&.strip,
      email: row_hash['email']&.strip&.downcase
    }

    # Create new person if not found
    person = Person.create!(
      first_name: name_parts&.first || 'Unknown',
      last_name: name_parts&.last || 'Unknown',
      email: person_data[:email].presence || "unknown_#{SecureRandom.hex(4)}@example.com"
    )
    return person, true
  end

  def parse_assignment_data(row_hash, row_num)
    {
      title: row_hash['assignment_name']&.strip,
      tagline: row_hash['assignment_description']&.strip,
      row: row_num
    }
  end

  def parse_tenure_data(row_hash, row_num)
    energy_percentage = parse_energy_percentage(row_hash['anticipated_energy_percentage'])
    start_date = parse_date(row_hash['assignment_tenure_start_date'])
    end_date = parse_date(row_hash['assignment_tenure_end_date'])

    {
      anticipated_energy_percentage: energy_percentage,
      started_at: start_date,
      ended_at: end_date,
      row: row_num
    }
  end

  def parse_check_in_data(row_hash, row_num)
    check_in_date = parse_date(row_hash['check_in_date'])
    energy_percentage = parse_energy_percentage(row_hash['energy_percentage'])
    manager_rating = parse_rating(row_hash['manager_rating'])
    employee_rating = parse_rating(row_hash['employee_rating'])
    official_rating = parse_rating(row_hash['official_rating'])

    {
      check_in_started_on: check_in_date,
      actual_energy_percentage: energy_percentage,
      manager_rating: manager_rating,
      employee_rating: employee_rating,
      official_rating: official_rating,
      manager_private_notes: row_hash['manager_private_notes']&.strip,
      employee_private_notes: row_hash['employee_private_notes']&.strip,
      row: row_num
    }
  end

  def extract_url_from_assignment_name(assignment_name)
    return nil unless assignment_name.present?
    
    match = assignment_name.match(URL_REGEX)
    match ? match[1] : nil
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
end
