require 'rails_helper'

RSpec.describe EmploymentDataUploadParser do
  # Sample XLSX content (simplified for testing)
  let(:valid_xlsx_content) do
    # This is a minimal valid XLSX structure
    File.read(Rails.root.join('spec', 'fixtures', 'sample_employment_data.xlsx'))
  rescue Errno::ENOENT
    # Fallback: create a simple XLSX-like content for testing
    "PK\x03\x04\x14\x00\x00\x00\x08\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
  end

  let(:invalid_content) { "not an xlsx file" }
  let(:empty_content) { "" }

  describe '#initialize' do
    let(:parser) { described_class.new(valid_xlsx_content) }

    it 'sets file_content and initializes errors and parsed_data' do
      expect(parser.file_content).to eq(valid_xlsx_content)
      expect(parser.errors).to eq([])
      expect(parser.parsed_data).to eq({})
    end

    it 'handles base64 encoded content' do
      base64_content = Base64.strict_encode64(valid_xlsx_content)
      parser = described_class.new(base64_content)
      expect(parser.file_content).to eq(base64_content)
      expect(parser.errors).to eq([])
      expect(parser.parsed_data).to eq({})
    end
  end

  describe '#parse' do
    context 'with invalid file content' do
      let(:parser) { described_class.new(invalid_content) }

      it 'returns false and adds error' do
        expect(parser.parse).to be false
        expect(parser.errors).to include('File does not appear to be a valid XLSX file')
      end
    end

    context 'with empty file content' do
      let(:parser) { described_class.new(empty_content) }

      it 'returns false and adds error' do
        expect(parser.parse).to be false
        expect(parser.errors).to include('File content is required')
      end
    end

    context 'with valid XLSX content' do
      let(:parser) { described_class.new(valid_xlsx_content) }

      before do
        # Mock the Roo::Spreadsheet to return test data
        allow(Roo::Spreadsheet).to receive(:open).and_return(mock_spreadsheet)
        allow(mock_spreadsheet).to receive(:sheet).and_return(mock_sheet)
      end

      let(:mock_spreadsheet) { double('spreadsheet') }
      let(:mock_sheet) { double('sheet') }

      context 'with base64 encoded content' do
        let(:parser) { described_class.new(Base64.strict_encode64(valid_xlsx_content)) }

        before do
          allow(mock_sheet).to receive(:row).with(1).and_return(['name', 'email'])
          allow(mock_sheet).to receive(:last_row).and_return(1)
        end

        it 'parses base64 encoded content correctly' do
          expect(parser.parse).to be true
          expect(parser.errors).to be_empty
        end
      end

      context 'with missing headers' do
        before do
          allow(mock_sheet).to receive(:row).with(1).and_return(['name']) # Missing required headers
          allow(mock_sheet).to receive(:last_row).and_return(1)
        end

        it 'returns false and adds error about missing headers' do
          expect(parser.parse).to be false
          expect(parser.errors).to include(/File must contain at least one of these headers/)
        end
      end

      context 'with header aliases' do
        before do
          allow(mock_sheet).to receive(:row).with(1).and_return(alias_headers)
          allow(mock_sheet).to receive(:last_row).and_return(2)
          allow(mock_sheet).to receive(:row).with(2).and_return(alias_data_row)
        end

        let(:alias_headers) do
          [
            'Employee', 'Assignment Name', 'Date of Check-In', 'Most Recent Actual Calorie %',
            'Personal Alignment', 'Anticipated Calories', 'Manager Rating', 'Manager Notes',
            'Employee Rating', 'Employee Notes', 'Final Agreed Rating'
          ]
        end

        let(:alias_data_row) do
          [
            'John Doe', 'Software Engineer [https://example.com/job]', '2024-01-15', '85',
            'Aligned with company goals', '90', 'exceeding', 'Great leadership skills',
            'meeting', 'Feeling good about progress', 'exceeding'
          ]
        end

        it 'parses data using header aliases correctly' do
          expect(parser.parse).to be true
          expect(parser.errors).to be_empty
          
          # Check that people data was parsed with auto-generated email
          people = parser.preview_actions[:people]
          expect(people.length).to eq(1)
          expect(people.first['name']).to eq('John Doe')
          expect(people.first['email']).to eq('John Doe@careerplug.com')
          
          # Check that assignments data was parsed
          assignments = parser.preview_actions[:assignments]
          expect(assignments.length).to eq(1)
          expect(assignments.first['assignment_name']).to eq('Software Engineer [https://example.com/job]')
          
          # Check that assignment tenures data was parsed
          tenures = parser.preview_actions[:assignment_tenures]
          expect(tenures.length).to eq(1)
          expect(tenures.first['anticipated_energy_percentage']).to eq(90)
          
          # Check that assignment check-ins data was parsed
          check_ins = parser.preview_actions[:assignment_check_ins]
          expect(check_ins.length).to eq(1)
          expect(check_ins.first['check_in_date']).to eq(Date.new(2024, 1, 15))
          expect(check_ins.first['energy_percentage']).to eq(85)
          expect(check_ins.first['manager_rating']).to eq('exceeding')
          expect(check_ins.first['employee_rating']).to eq('meeting')
          expect(check_ins.first['official_rating']).to eq('exceeding')
          expect(check_ins.first['manager_private_notes']).to eq('Great leadership skills')
          expect(check_ins.first['employee_private_notes']).to eq('Feeling good about progress')
          expect(check_ins.first['employee_personal_alignment']).to eq('Aligned with company goals')
          
          # Check that external references were extracted
          external_refs = parser.preview_actions[:external_references]
          expect(external_refs.length).to eq(1)
          expect(external_refs.first['external_url']).to eq('https://example.com/job')
        end

        it 'provides enhanced preview actions with find operations' do
          expect(parser.parse).to be true
          
          enhanced_actions = parser.enhanced_preview_actions
          
          # Check people enhancement
          people = enhanced_actions[:people]
          expect(people.length).to eq(1)
          expect(people.first['action']).to eq('create')
          expect(people.first['will_create']).to be true
          expect(people.first['existing_id']).to be_nil
          
          # Check assignments enhancement
          assignments = enhanced_actions[:assignments]
          expect(assignments.length).to eq(1)
          expect(assignments.first['action']).to eq('create')
          expect(assignments.first['will_create']).to be true
          expect(assignments.first['existing_id']).to be_nil
          
          # Check tenures enhancement with references
          tenures = enhanced_actions[:assignment_tenures]
          expect(tenures.length).to eq(1)
          expect(tenures.first['action']).to eq('create')
          expect(tenures.first['will_create']).to be true
          expect(tenures.first['person_reference']).to be_present
          expect(tenures.first['assignment_reference']).to be_present
          expect(tenures.first['person_reference']['name']).to eq('John Doe')
          expect(tenures.first['assignment_reference']['assignment_name']).to eq('Software Engineer [https://example.com/job]')
          
          # Check check-ins enhancement with references
          check_ins = enhanced_actions[:assignment_check_ins]
          expect(check_ins.length).to eq(1)
          expect(check_ins.first['action']).to eq('create')
          expect(check_ins.first['will_create']).to be true
          expect(check_ins.first['person_reference']).to be_present
          expect(check_ins.first['assignment_reference']).to be_present
          expect(check_ins.first['person_reference']['name']).to eq('John Doe')
          expect(check_ins.first['assignment_reference']['assignment_name']).to eq('Software Engineer [https://example.com/job]')
        end

        it 'handles nil/blank data safely in enhancement methods' do
          # Test with empty parsed data
          parser.instance_variable_set(:@parsed_data, {})
          
          enhanced_actions = parser.enhanced_preview_actions
          expect(enhanced_actions).to eq({})
          
          # Test with nil values
          parser.instance_variable_set(:@parsed_data, {
            people: nil,
            assignments: nil,
            assignment_tenures: nil,
            assignment_check_ins: nil,
            external_references: nil
          })
          
          enhanced_actions = parser.enhanced_preview_actions
          expect(enhanced_actions[:people]).to eq([])
          expect(enhanced_actions[:assignments]).to eq([])
          expect(enhanced_actions[:assignment_tenures]).to eq([])
          expect(enhanced_actions[:assignment_check_ins]).to eq([])
          expect(enhanced_actions[:external_references]).to eq([])
        end
      end

      context 'with valid headers and data' do
        before do
          allow(mock_sheet).to receive(:row).with(1).and_return(valid_headers)
          allow(mock_sheet).to receive(:last_row).and_return(3)
          allow(mock_sheet).to receive(:row).with(2).and_return(valid_data_row_1)
          allow(mock_sheet).to receive(:row).with(3).and_return(valid_data_row_2)
        end

        let(:valid_headers) do
          [
            'name', 'email', 'assignment_name', 'assignment_description',
            'anticipated_energy_percentage', 'assignment_tenure_start_date',
            'manager_private_notes', 'check_in_date'
          ]
        end

        let(:valid_data_row_1) do
          [
            'John Doe', 'john@example.com', 'Software Engineer [https://example.com/job]',
            'Build amazing software', '80', '2024-01-01', 'Great work!', '2024-01-15'
          ]
        end

        let(:valid_data_row_2) do
          [
            'Jane Smith', 'jane@example.com', 'Product Manager',
            'Lead product development', '90', '2024-01-01', 'Excellent leadership', '2024-01-15'
          ]
        end

        it 'returns true and parses data correctly' do
          expect(parser.parse).to be true
          expect(parser.errors).to be_empty
          
          # Check that people data was parsed
          people = parser.parsed_data[:people]
          expect(people.length).to eq(2)
          expect(people.first['name']).to eq('John Doe')
          expect(people.first['email']).to eq('john@example.com')
          expect(people.last['name']).to eq('Jane Smith')
          expect(people.last['email']).to eq('jane@example.com')
          
          # Check that assignments data was parsed
          assignments = parser.parsed_data[:assignments]
          expect(assignments.length).to eq(2)
          expect(assignments.first['assignment_name']).to eq('Software Engineer [https://example.com/job]')
          expect(assignments.first['assignment_description']).to eq('Build amazing software')
          expect(assignments.last['assignment_name']).to eq('Product Manager')
          expect(assignments.last['assignment_description']).to eq('Lead product development')
          
          # Check that assignment tenures data was parsed
          tenures = parser.parsed_data[:assignment_tenures]
          expect(tenures.length).to eq(2)
          expect(tenures.first['anticipated_energy_percentage']).to eq(80)
          expect(tenures.last['anticipated_energy_percentage']).to eq(90)
          
          # Check that assignment check-ins data was parsed
          check_ins = parser.parsed_data[:assignment_check_ins]
          expect(check_ins.length).to eq(2)
          expect(check_ins.first['check_in_date']).to eq(Date.new(2024, 1, 15))
          expect(check_ins.first['manager_private_notes']).to eq('Great work!')
          expect(check_ins.last['check_in_date']).to eq(Date.new(2024, 1, 15))
          expect(check_ins.last['manager_private_notes']).to eq('Excellent leadership')
        end

        it 'defaults check_in_date to today when not provided' do
          # Create a data row without check_in_date
          data_row_without_date = [
            'John Doe', 'john@example.com', 'Software Engineer',
            'Build amazing software', '80', '2024-01-01', 'Great work!', nil
          ]
          
          allow(mock_sheet).to receive(:row).with(2).and_return(data_row_without_date)
          allow(mock_sheet).to receive(:last_row).and_return(2)
          
          expect(parser.parse).to be true
          expect(parser.errors).to be_empty
          
          check_ins = parser.parsed_data[:assignment_check_ins]
          expect(check_ins.length).to eq(1)
          expect(check_ins.first['check_in_date']).to eq(Date.current)
        end

        it 'extracts URLs from assignment names' do
          expect(parser.parse).to be true
          
          external_refs = parser.parsed_data[:external_references]
          expect(external_refs.length).to eq(1)
          expect(external_refs.first['external_url']).to eq('https://example.com/job')
        end

        it 'parses assignment data correctly' do
          expect(parser.parse).to be true
          
          assignments = parser.parsed_data[:assignments]
          expect(assignments.length).to eq(2)
          expect(assignments.first['assignment_name']).to eq('Software Engineer [https://example.com/job]')
          expect(assignments.first['assignment_description']).to eq('Build amazing software')
        end
      end
    end
  end

  describe 'hyperlink extraction' do
    let(:file_path) { Rails.root.join('spec/fixtures/files/real_test.xlsx') }
    let(:file_content) { Base64.strict_encode64(File.read(file_path)) }
    let(:parser) { EmploymentDataUploadParser.new(file_content) }

    it 'extracts hyperlinks from Excel file' do
      result = parser.parse
      if !result
        puts "Parser failed with errors:"
        puts parser.errors
      end
      
      expect(parser.parse).to be true
      expect(parser.errors).to be_empty
      
      external_refs = parser.parsed_data[:external_references]
      expect(external_refs).not_to be_empty
      
      # Check that we found some Figma URLs
      figma_urls = external_refs.select { |ref| ref['external_url'].include?('figma.com') }
      expect(figma_urls.length).to be > 0
      
      # Check that URLs are properly mapped to assignment names
      figma_urls.each do |ref|
        expect(ref['assignment_name']).to be_present
        expect(ref['external_url']).to match(/^https:\/\/www\.figma\.com/)
        expect(ref['row']).to be_present
      end
      
      puts "Found #{external_refs.length} external references:"
      external_refs.each do |ref|
        puts "  #{ref['assignment_name']} -> #{ref['external_url']}"
      end
    end
  end

  describe '#preview_actions' do
    context 'when no data has been parsed' do
      let(:parser) { described_class.new(valid_xlsx_content) }

      it 'returns empty hash' do
        expect(parser.preview_actions).to eq({})
      end
    end

    context 'when data has been parsed' do
      let(:parser) { described_class.new(valid_xlsx_content) }

      before do
        parser.instance_variable_set(:@parsed_data, {
          people: [{ name: 'John Doe' }],
          assignments: [{ title: 'Engineer' }],
          assignment_tenures: [{ energy: 80 }],
          assignment_check_ins: [{ notes: 'Good work' }],
          external_references: [{ url: 'https://example.com' }]
        })
      end

      it 'returns structured preview actions' do
        actions = parser.preview_actions
        
        expect(actions[:people].length).to eq(1)
        expect(actions[:assignments].length).to eq(1)
        expect(actions[:assignment_tenures].length).to eq(1)
        expect(actions[:assignment_check_ins].length).to eq(1)
        expect(actions[:external_references].length).to eq(1)
      end
    end
  end

  describe 'private methods' do
    let(:parser) { described_class.new(valid_xlsx_content) }

    describe '#parse_energy_percentage' do
      it 'parses valid percentages' do
        expect(parser.send(:parse_energy_percentage, '80')).to eq(80)
        expect(parser.send(:parse_energy_percentage, '80%')).to eq(80)
        expect(parser.send(:parse_energy_percentage, 90)).to eq(90)
      end

      it 'handles invalid percentages' do
        expect(parser.send(:parse_energy_percentage, '150')).to be_nil
        expect(parser.send(:parse_energy_percentage, '-10')).to be_nil
        expect(parser.send(:parse_energy_percentage, 'abc')).to be_nil
        expect(parser.send(:parse_energy_percentage, '')).to be_nil
      end
    end

    describe '#parse_date' do
      it 'parses various date formats' do
        expect(parser.send(:parse_date, '2024-01-01')).to eq(Date.new(2024, 1, 1))
        expect(parser.send(:parse_date, Date.new(2024, 1, 1))).to eq(Date.new(2024, 1, 1))
        expect(parser.send(:parse_date, Time.new(2024, 1, 1))).to eq(Date.new(2024, 1, 1))
      end

      it 'handles Excel numeric dates' do
        # Excel date 45000 represents approximately 2023-03-15
        excel_date = 45000
        parsed_date = parser.send(:parse_date, excel_date)
        expect(parsed_date).to be_a(Date)
        expect(parsed_date.year).to be > 2020
      end

      it 'returns nil for invalid dates' do
        expect(parser.send(:parse_date, 'invalid')).to be_nil
        expect(parser.send(:parse_date, '')).to be_nil
      end
    end

    describe '#parse_rating' do
      it 'parses valid ratings' do
        expect(parser.send(:parse_rating, 'working_to_meet')).to eq('working_to_meet')
        expect(parser.send(:parse_rating, 'MEETING')).to eq('meeting')
        expect(parser.send(:parse_rating, ' Exceeding ')).to eq('exceeding')
      end

      it 'returns nil for invalid ratings' do
        expect(parser.send(:parse_rating, 'excellent')).to be_nil
        expect(parser.send(:parse_rating, '')).to be_nil
        expect(parser.send(:parse_rating, nil)).to be_nil
      end
    end

    describe '#extract_url_from_assignment_name' do
      it 'extracts URLs from assignment names' do
        expect(parser.send(:extract_url_from_assignment_name, 'Engineer [https://example.com]')).to eq('https://example.com')
        expect(parser.send(:extract_url_from_assignment_name, 'Manager [http://test.org/job]')).to eq('http://test.org/job')
      end

      it 'returns nil when no URL is present' do
        expect(parser.send(:extract_url_from_assignment_name, 'Engineer')).to be_nil
        expect(parser.send(:extract_url_from_assignment_name, '')).to be_nil
        expect(parser.send(:extract_url_from_assignment_name, nil)).to be_nil
      end
    end

    describe '#generate_email_from_name' do
      it 'generates email by appending @careerplug.com to name' do
        expect(parser.send(:generate_email_from_name, 'John Doe')).to eq('John Doe@careerplug.com')
        expect(parser.send(:generate_email_from_name, 'Jane Smith')).to eq('Jane Smith@careerplug.com')
        expect(parser.send(:generate_email_from_name, 'Dr. Andrew Robinson III')).to eq('Dr. Andrew Robinson III@careerplug.com')
      end

      it 'handles edge cases' do
        expect(parser.send(:generate_email_from_name, '')).to eq('@careerplug.com')
        expect(parser.send(:generate_email_from_name, nil)).to eq('@careerplug.com')
      end
    end

    describe '#map_header_alias' do
      it 'maps user-friendly headers to internal field names' do
        expect(parser.send(:map_header_alias, 'Employee')).to eq('name')
        expect(parser.send(:map_header_alias, 'Assignment Name')).to eq('assignment_name')
        expect(parser.send(:map_header_alias, 'Date of Check-In')).to eq('check_in_date')
        expect(parser.send(:map_header_alias, 'Most Recent Actual Calorie %')).to eq('energy_percentage')
        expect(parser.send(:map_header_alias, 'Personal Alignment')).to eq('employee_personal_alignment')
        expect(parser.send(:map_header_alias, 'Anticipated Calories')).to eq('anticipated_energy_percentage')
        expect(parser.send(:map_header_alias, 'Manager Rating')).to eq('manager_rating')
        expect(parser.send(:map_header_alias, 'Manager Notes')).to eq('manager_private_notes')
        expect(parser.send(:map_header_alias, 'Employee Rating')).to eq('employee_rating')
        expect(parser.send(:map_header_alias, 'Employee Notes')).to eq('employee_private_notes')
        expect(parser.send(:map_header_alias, 'Final Agreed Rating')).to eq('official_rating')
      end

      it 'returns the original header if no alias exists' do
        expect(parser.send(:map_header_alias, 'Unknown Header')).to eq('Unknown Header')
        expect(parser.send(:map_header_alias, 'name')).to eq('name')
        expect(parser.send(:map_header_alias, 'email')).to eq('email')
      end
    end
  end
end
