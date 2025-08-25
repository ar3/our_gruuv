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

      context 'with missing headers' do
        before do
          allow(mock_sheet).to receive(:row).with(1).and_return(['name']) # Missing required headers
          allow(mock_sheet).to receive(:last_row).and_return(1)
        end

        it 'returns false and adds error about missing headers' do
          expect(parser.parse).to be false
          expect(parser.errors).to include(/Missing basic required headers/)
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
          
          # Check parsed data structure
          expect(parser.parsed_data[:people].length).to eq(2)
          expect(parser.parsed_data[:assignments].length).to eq(2)
          expect(parser.parsed_data[:external_references].length).to eq(1)
        end

        it 'extracts URLs from assignment names' do
          parser.parse
          external_refs = parser.parsed_data[:external_references]
          
          expect(external_refs.first[:url]).to eq('https://example.com/job')
          expect(external_refs.first[:assignment_name]).to eq('Software Engineer [https://example.com/job]')
        end

        it 'parses person data correctly' do
          parser.parse
          people = parser.parsed_data[:people]
          
          expect(people.first[:name]).to eq('John Doe')
          expect(people.first[:email]).to eq('john@example.com')
          expect(people.first[:row]).to eq(2)
        end

        it 'parses assignment data correctly' do
          parser.parse
          assignments = parser.parsed_data[:assignments]
          
          expect(assignments.first[:title]).to eq('Software Engineer [https://example.com/job]')
          expect(assignments.first[:tagline]).to eq('Build amazing software')
        end
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
  end
end
