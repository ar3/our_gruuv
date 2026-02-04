require 'rails_helper'

RSpec.describe UnassignedEmployeeUploadParser, type: :service do
  let(:valid_csv_content) do
    <<~CSV
      Name,Preferred Name,Email,Start Date,Location,Gender,Department,Employment Type,Manager,Country,Manager Email,Job Title,Job Title Level
      John Doe,John,john.doe@company.com,2024-01-15,New York,male,Engineering,full_time,Jane Smith,USA,jane.smith@company.com,Software Engineer,mid
      Jane Smith,Jane,jane.smith@company.com,2024-01-10,San Francisco,female,Engineering,full_time,Bob Johnson,USA,bob.johnson@company.com,Senior Engineer,senior
      Bob Johnson,Bob,bob.johnson@company.com,2023-12-01,Remote,male,Engineering,full_time,,USA,,Engineering Manager,lead
    CSV
  end

  let(:invalid_csv_content) do
    <<~CSV
      Invalid Header,Another Header
      Value1,Value2
    CSV
  end

  let(:parser) { described_class.new(valid_csv_content) }

  describe '#initialize' do
    it 'sets file_content and initializes errors and parsed_data' do
      expect(parser.file_content).to eq(valid_csv_content)
      expect(parser.errors).to eq([])
      expect(parser.parsed_data).to eq({})
    end
  end

  describe '#parse' do
    context 'with valid CSV content' do
      it 'returns true and populates parsed_data' do
        expect(parser.parse).to be true
        expect(parser.errors).to be_empty
        expect(parser.parsed_data).to have_key(:unassigned_employees)
        expect(parser.parsed_data).to have_key(:departments)
        expect(parser.parsed_data).to have_key(:managers)
      end

      it 'parses unassigned employees correctly' do
        parser.parse
        employees = parser.parsed_data[:unassigned_employees]
        
        expect(employees.length).to eq(3)
        
        first_employee = employees.first
        expect(first_employee['name']).to eq('John Doe')
        expect(first_employee['preferred_name']).to eq('John')
        expect(first_employee['email']).to eq('john.doe@company.com')
        expect(first_employee['start_date']).to eq(Date.parse('2024-01-15'))
        expect(first_employee['location']).to eq('New York')
        expect(first_employee['gender']).to eq('man')
        expect(first_employee['department']).to eq('Engineering')
        expect(first_employee['employment_type']).to eq('full_time')
        expect(first_employee['manager_name']).to eq('Jane Smith')
        expect(first_employee['country']).to eq('USA')
        expect(first_employee['manager_email']).to eq('jane.smith@company.com')
        expect(first_employee['job_title']).to eq('Software Engineer')
        expect(first_employee['job_title_level']).to eq('mid')
      end

      it 'parses departments correctly' do
        parser.parse
        departments = parser.parsed_data[:departments]
        
        expect(departments.length).to eq(1) # Only unique departments
        expect(departments.first['name']).to eq('Engineering')
      end

      it 'parses managers correctly' do
        parser.parse
        managers = parser.parsed_data[:managers]
        
        expect(managers.length).to eq(2) # Jane Smith and Bob Johnson
        expect(managers.map { |m| m['name'] }).to contain_exactly('Jane Smith', 'Bob Johnson')
      end
    end

    context 'with invalid CSV content' do
      let(:parser) { described_class.new(invalid_csv_content) }

      it 'returns false and adds errors' do
        expect(parser.parse).to be false
        expect(parser.errors).not_to be_empty
        expect(parser.errors.first).to include('Missing required headers')
      end
    end

    context 'with empty content' do
      let(:parser) { described_class.new('') }

      it 'returns false and adds errors' do
        expect(parser.parse).to be false
        expect(parser.errors).to include('File content is required')
      end
    end

    context 'with missing required headers' do
      let(:missing_headers_csv) do
        <<~CSV
          Invalid Header,Another Header
          Value1,Value2
        CSV
      end

      let(:parser) { described_class.new(missing_headers_csv) }

      it 'returns false and adds errors' do
        expect(parser.parse).to be false
        expect(parser.errors).to include('Missing required headers: Name, Email')
      end
    end

    context 'with empty rows' do
      let(:csv_with_empty_rows) do
        <<~CSV
          Name,Email,Start Date
          John Doe,john.doe@company.com,2024-01-15
          ,,
          Jane Smith,jane.smith@company.com,2024-01-10
        CSV
      end

      let(:parser) { described_class.new(csv_with_empty_rows) }

      it 'skips empty rows and parses valid ones' do
        parser.parse
        employees = parser.parsed_data[:unassigned_employees]
        
        expect(employees.length).to eq(2)
        expect(employees.map { |e| e['name'] }).to contain_exactly('John Doe', 'Jane Smith')
      end
    end
  end

  describe '#preview_actions' do
    it 'returns parsed data when available' do
      parser.parse
      preview = parser.preview_actions
      
      expect(preview).to have_key(:unassigned_employees)
      expect(preview).to have_key(:departments)
      expect(preview).to have_key(:managers)
    end

    it 'returns empty hash when no data parsed' do
      preview = parser.preview_actions
      expect(preview).to eq({})
    end
  end

  describe '#enhanced_preview_actions' do
    before do
      # Create some test data
      @organization = create(:organization, :company)
      @department = create(:department, company: @organization, name: 'Engineering')
      @existing_person = create(:person, email: 'existing@company.com', first_name: 'Existing', last_name: 'Person')
    end

    it 'enhances unassigned employees with existing person information' do
      csv_with_existing_person = <<~CSV
        Name,Email,Start Date
        Existing Person,existing@company.com,2024-01-15
        New Person,new@company.com,2024-01-20
      CSV

      parser = described_class.new(csv_with_existing_person)
      parser.parse
      preview = parser.enhanced_preview_actions
      
      employees = preview[:unassigned_employees]
      expect(employees.length).to eq(2)
      
      existing_employee = employees.find { |e| e['email'] == 'existing@company.com' }
      expect(existing_employee['action']).to eq('update')
      expect(existing_employee['existing_id']).to eq(@existing_person.id)
      expect(existing_employee['will_create']).to be false
      
      new_employee = employees.find { |e| e['email'] == 'new@company.com' }
      expect(new_employee['action']).to eq('create')
      expect(new_employee['existing_id']).to be_nil
      expect(new_employee['will_create']).to be true
    end

    it 'enhances departments with existing department information' do
      csv_with_existing_department = <<~CSV
        Name,Email,Department
        John Doe,john@company.com,Engineering
        Jane Smith,jane@company.com,Marketing
      CSV

      parser = described_class.new(csv_with_existing_department)
      parser.parse
      preview = parser.enhanced_preview_actions
      
      departments = preview[:departments]
      expect(departments.length).to eq(2)
      
      existing_department = departments.find { |d| d['name'] == 'Engineering' }
      expect(existing_department['action']).to eq('update')
      expect(existing_department['existing_id']).to eq(@department.id)
      expect(existing_department['will_create']).to be false
      
      new_department = departments.find { |d| d['name'] == 'Marketing' }
      expect(new_department['action']).to eq('create')
      expect(new_department['existing_id']).to be_nil
      expect(new_department['will_create']).to be true
    end
  end

  describe 'private methods' do
    describe '#parse_date' do
      it 'parses valid dates correctly' do
        parser = described_class.new('')
        expect(parser.send(:parse_date, '2024-01-15')).to eq(Date.parse('2024-01-15'))
        expect(parser.send(:parse_date, '01/15/2024')).to eq(Date.parse('2024-01-15'))
      end

      it 'returns nil for invalid dates' do
        parser = described_class.new('')
        expect(parser.send(:parse_date, 'invalid')).to be_nil
        expect(parser.send(:parse_date, '')).to be_nil
      end
    end

    describe '#parse_gender' do
      it 'parses valid genders correctly' do
        parser = described_class.new('')
        expect(parser.send(:parse_gender, 'male')).to eq('man')
        expect(parser.send(:parse_gender, 'female')).to eq('woman')
        expect(parser.send(:parse_gender, 'non_binary')).to eq('non_binary')
      end

      it 'returns nil for invalid genders' do
        parser = described_class.new('')
        expect(parser.send(:parse_gender, 'invalid')).to be_nil
        expect(parser.send(:parse_gender, '')).to be_nil
      end
    end

    describe '#parse_employment_type' do
      it 'parses valid employment types correctly' do
        parser = described_class.new('')
        expect(parser.send(:parse_employment_type, 'full_time')).to eq('full_time')
        expect(parser.send(:parse_employment_type, 'part_time')).to eq('part_time')
        expect(parser.send(:parse_employment_type, 'contract')).to eq('contract')
      end

      it 'returns nil for invalid employment types' do
        parser = described_class.new('')
        expect(parser.send(:parse_employment_type, 'invalid')).to be_nil
        expect(parser.send(:parse_employment_type, '')).to be_nil
      end
    end

    describe '#parse_job_title_level' do
      it 'parses valid job title levels correctly' do
        parser = described_class.new('')
        expect(parser.send(:parse_job_title_level, 'entry')).to eq('entry')
        expect(parser.send(:parse_job_title_level, 'mid')).to eq('mid')
        expect(parser.send(:parse_job_title_level, 'senior')).to eq('senior')
      end

      it 'returns nil for invalid job title levels' do
        parser = described_class.new('')
        expect(parser.send(:parse_job_title_level, 'invalid')).to be_nil
        expect(parser.send(:parse_job_title_level, '')).to be_nil
      end
    end

    describe '#generate_email_from_name' do
      it 'generates email from full name' do
        parser = described_class.new('')
        expect(parser.send(:generate_email_from_name, 'John Doe')).to eq('john.doe@company.com')
        expect(parser.send(:generate_email_from_name, 'Jane Smith')).to eq('jane.smith@company.com')
      end

      it 'handles single names' do
        parser = described_class.new('')
        expect(parser.send(:generate_email_from_name, 'John')).to eq('john@company.com')
      end

      it 'returns nil for blank names' do
        parser = described_class.new('')
        expect(parser.send(:generate_email_from_name, '')).to be_nil
        expect(parser.send(:generate_email_from_name, nil)).to be_nil
      end
    end

    describe '#generate_name_from_email' do
      it 'generates name from email' do
        parser = described_class.new('')
        expect(parser.send(:generate_name_from_email, 'john.doe@company.com')).to eq('John Doe')
        expect(parser.send(:generate_name_from_email, 'jane.smith@company.com')).to eq('Jane Smith')
      end

      it 'handles single part emails' do
        parser = described_class.new('')
        expect(parser.send(:generate_name_from_email, 'john@company.com')).to eq('John')
      end

      it 'returns nil for blank emails' do
        parser = described_class.new('')
        expect(parser.send(:generate_name_from_email, '')).to be_nil
        expect(parser.send(:generate_name_from_email, nil)).to be_nil
      end
    end
  end
end
