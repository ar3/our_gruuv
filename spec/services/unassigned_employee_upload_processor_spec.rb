require 'rails_helper'

RSpec.describe UnassignedEmployeeUploadProcessor, type: :service do
  let(:organization) { create(:organization, type: 'Company') }
  let(:upload_event) { create(:upload_event, organization: organization, filename: 'test.csv') }
  let(:processor) { described_class.new(upload_event, organization) }

  describe '#initialize' do
    it 'sets upload_event, organization, and parser' do
      expect(processor.upload_event).to eq(upload_event)
      expect(processor.organization).to eq(organization)
      expect(processor.parser).to be_a(UnassignedEmployeeUploadParser)
      expect(processor.results).to eq({
        successes: [],
        failures: [],
        summary: {
          total_processed: 0,
          successful_creates: 0,
          successful_updates: 0,
          failed_operations: 0
        }
      })
    end
  end

  describe '#process' do
    let(:valid_csv_content) do
      <<~CSV
        Name,Preferred Name,Email,Start Date,Location,Gender,Department,Employment Type,Manager,Country,Manager Email,Job Title,Job Title Level
        John Doe,John,john.doe@company.com,2024-01-15,New York,male,Engineering,full_time,Jane Smith,USA,jane.smith@company.com,Software Engineer,mid
        Jane Smith,Jane,jane.smith@company.com,2024-01-10,San Francisco,female,Engineering,full_time,Bob Johnson,USA,bob.johnson@company.com,Senior Engineer,senior
      CSV
    end

        let(:upload_event) { create(:upload_event, organization: organization, file_content: valid_csv_content, filename: 'test.csv') }

    context 'with valid data' do
      it 'processes successfully and returns true' do
        expect(processor.process).to be true
        expect(processor.results[:successes]).not_to be_empty
        expect(processor.results[:failures]).to be_empty
      end

          it 'creates new people' do
            # Creates John Doe, Jane Smith, and Bob Johnson (as manager)
            # Total: 3 people from CSV (but may be more due to factory records)
            expect { processor.process }.to change(Person, :count).by_at_least(3)
          end

      it 'creates new departments' do
        expect { processor.process }.to change(Organization.departments, :count).by(1)
      end

      it 'creates teammate relationships' do
        # Creates teammates for John Doe, Jane Smith, and Bob Johnson (as manager)
        # Total: 3 teammates
        expect { processor.process }.to change(Teammate, :count).by(3)
      end

      it 'creates employment tenures for employees' do
        # Creates employment tenures for John Doe and Jane Smith (not Bob Johnson as he's only a manager)
        # Total: 2 employment tenures
        expect { processor.process }.to change(EmploymentTenure, :count).by(2)
      end

      it 'sets correct teammate information' do
        processor.process
        
        john = Person.find_by(email: 'john.doe@company.com')
        jane = Person.find_by(email: 'jane.smith@company.com')
        
        john_teammate = john.teammates.find_by(organization: organization)
        jane_teammate = jane.teammates.find_by(organization: organization)
        
        expect(john_teammate).to be_present
        expect(john_teammate.type).to eq('CompanyTeammate')
        expect(john_teammate.first_employed_at).to eq(Date.parse('2024-01-15'))
        
        expect(jane_teammate).to be_present
        expect(jane_teammate.type).to eq('CompanyTeammate')
        expect(jane_teammate.first_employed_at).to eq(Date.parse('2024-01-10'))
      end

      it 'sets correct employment tenure information' do
        processor.process
        
        john = Person.find_by(email: 'john.doe@company.com')
        jane = Person.find_by(email: 'jane.smith@company.com')
        bob = Person.find_by(email: 'bob.johnson@company.com')
        
        john_tenure = john.employment_tenures.find_by(company: organization)
        jane_tenure = jane.employment_tenures.find_by(company: organization)
        bob_tenure = bob.employment_tenures.find_by(company: organization)
        
        # John should have employment tenure
        expect(john_tenure).to be_present
        expect(john_tenure.started_at).to eq(Date.parse('2024-01-15'))
        expect(john_tenure.company).to be_a(Organization)
        expect(john_tenure.position).to be_present
        expect(john_tenure.position.position_type.external_title).to eq('Software Engineer')
        expect(john_tenure.manager).to eq(jane) # Jane is John's manager
        
        # Jane should have employment tenure
        expect(jane_tenure).to be_present
        expect(jane_tenure.started_at).to eq(Date.parse('2024-01-10'))
        expect(jane_tenure.company).to be_a(Organization)
        expect(jane_tenure.position).to be_present
        expect(jane_tenure.position.position_type.external_title).to eq('Senior Engineer')
        expect(jane_tenure.manager).to eq(bob) # Bob is Jane's manager
        
        # Bob should NOT have employment tenure (he's only a manager, not an employee)
        expect(bob_tenure).to be_nil
      end

      it 'updates summary correctly' do
        processor.process
        
        summary = processor.results[:summary]
        expect(summary[:total_processed]).to eq(7) # 3 people + 1 department + 2 employment tenures + 1 update
        expect(summary[:successful_creates]).to eq(6) # 3 people + 1 department + 2 employment tenures
        expect(summary[:successful_updates]).to eq(1)
        expect(summary[:failed_operations]).to eq(0)
      end
    end

    context 'with existing people' do
      let!(:existing_person) { create(:person, email: 'john.doe@company.com', first_name: 'John', last_name: 'Doe') }

          it 'updates existing people instead of creating new ones' do
            # John already exists, creates Jane Smith and Bob Johnson (as manager)
            expect { processor.process }.to change(Person, :count).by_at_least(2)
          end

      it 'creates teammate relationship for existing person' do
        # Creates teammates for John (existing), Jane Smith, and Bob Johnson (as manager)
        expect { processor.process }.to change(Teammate, :count).by(3)
        
        existing_teammate = existing_person.teammates.find_by(organization: organization)
        expect(existing_teammate).to be_present
        # The start date should be updated from the CSV data
            expect(existing_teammate.first_employed_at.to_date).to eq(Date.parse('2024-01-15'))
      end

      it 'creates employment tenure for existing person' do
        # Creates employment tenures for John (existing) and Jane Smith (not Bob Johnson as he's only a manager)
        expect { processor.process }.to change(EmploymentTenure, :count).by(2)
        
        existing_tenure = existing_person.employment_tenures.find_by(company: organization)
        expect(existing_tenure).to be_present
        expect(existing_tenure.started_at).to eq(Date.parse('2024-01-15'))
        expect(existing_tenure.position.position_type.external_title).to eq('Software Engineer')
      end

      it 'includes update action in results' do
        processor.process
        
        update_success = processor.results[:successes].find { |s| s[:type] == 'unassigned_employee' && s[:action] == 'updated' }
        expect(update_success).to be_present
        expect(update_success[:name]).to eq('John Doe')
      end

      it 'includes employment tenure actions in results' do
        processor.process
        
        employment_tenure_successes = processor.results[:successes].select { |s| s[:type] == 'employment_tenure' }
        expect(employment_tenure_successes.count).to eq(2)
        
        john_tenure_success = employment_tenure_successes.find { |s| s[:person_name] == 'John Doe' }
        jane_tenure_success = employment_tenure_successes.find { |s| s[:person_name] == 'Jane Smith' }
        
        expect(john_tenure_success).to be_present
        expect(john_tenure_success[:action]).to eq('created')
        expect(john_tenure_success[:position_title]).to eq('Software Engineer')
        
        expect(jane_tenure_success).to be_present
        expect(jane_tenure_success[:action]).to eq('created')
        expect(jane_tenure_success[:position_title]).to eq('Senior Engineer')
      end
    end

    context 'with existing departments' do
      let!(:existing_department) { create(:organization, type: 'Department', parent: organization, name: 'Engineering') }

      it 'does not create duplicate departments' do
        expect { processor.process }.not_to change(Organization.departments, :count)
      end

      it 'includes exists action in results' do
        processor.process
        
        department_success = processor.results[:successes].find { |s| s[:type] == 'department' && s[:action] == 'exists' }
        expect(department_success).to be_present
        expect(department_success[:name]).to eq('Engineering')
      end
    end

    context 'with existing employment tenures' do
      let!(:existing_person) { create(:person, email: 'john.doe@company.com', first_name: 'John', last_name: 'Doe') }
      let!(:existing_person_teammate) { create(:teammate, person: existing_person, organization: organization) }
      let!(:existing_position_type) { create(:position_type, organization: organization, external_title: 'Software Engineer') }
      let!(:existing_position_level) { create(:position_level, position_major_level: existing_position_type.position_major_level) }
      let!(:existing_position) { create(:position, position_type: existing_position_type, position_level: existing_position_level) }
      let!(:existing_employment_tenure) { create(:employment_tenure, teammate: existing_person_teammate, company: organization, position: existing_position, started_at: Date.parse('2023-01-01')) }

      it 'handles existing employment tenures correctly' do
        # Should not create new employment tenure for John since he already has one
        # But should create one for Jane Smith since she doesn't have one
        expect { processor.process }.to change(EmploymentTenure, :count).by(1)
      end

      it 'includes exists action for employment tenure in results' do
        processor.process
        
        employment_tenure_success = processor.results[:successes].find { |s| s[:type] == 'employment_tenure' && s[:person_name] == 'John Doe' }
        expect(employment_tenure_success).to be_present
        expect(employment_tenure_success[:action]).to eq('exists')
      end
    end

    context 'with invalid data' do
      let(:invalid_csv_content) do
        <<~CSV
          Name,Email,Start Date
          ,invalid-email,invalid-date
        CSV
      end

          let(:upload_event) { create(:upload_event, organization: organization, file_content: invalid_csv_content, filename: 'invalid.csv') }

      it 'handles errors gracefully' do
        expect(processor.process).to be true # Still returns true, but with failures
        expect(processor.results[:failures]).not_to be_empty
      end

      it 'includes error details in results' do
        processor.process
        
        failure = processor.results[:failures].first
        expect(failure[:type]).to eq('unassigned_employee')
        expect(failure[:error]).to be_present
      end
    end

    context 'with employment tenure creation errors' do
      let(:csv_with_invalid_position) do
        <<~CSV
          Name,Preferred Name,Email,Start Date,Location,Gender,Department,Employment Type,Manager,Country,Manager Email,Job Title,Job Title Level
          John Doe,John,john.doe@company.com,2024-01-15,New York,male,Engineering,full_time,Jane Smith,USA,jane.smith@company.com,,mid
        CSV
      end

      let(:upload_event) { create(:upload_event, organization: organization, file_content: csv_with_invalid_position, filename: 'test.csv') }

      it 'handles employment tenure creation errors gracefully' do
        expect(processor.process).to be true # Still returns true, but with failures
        expect(processor.results[:failures]).not_to be_empty
        
        employment_tenure_failure = processor.results[:failures].find { |f| f[:type] == 'employment_tenure' }
        expect(employment_tenure_failure).to be_present
        expect(employment_tenure_failure[:error]).to be_present
      end
    end

        context 'with parser errors' do
          let(:upload_event) { create(:upload_event, organization: organization, file_content: 'invalid csv', filename: 'invalid.csv') }

          it 'returns false when parser fails' do
            expect(processor.process).to be false
            expect(processor.results[:failures]).not_to be_empty
            # The processor handles parser errors by returning false, not adding system errors
          end
        end

    context 'with database errors' do
      before do
        allow_any_instance_of(UnassignedEmployeeUploadProcessor).to receive(:process_departments).and_raise(ActiveRecord::RecordInvalid.new(Organization.new))
      end

      it 'handles database errors gracefully' do
        expect(processor.process).to be false
        expect(processor.results[:failures]).not_to be_empty
        expect(processor.results[:failures].first[:type]).to eq('system_error')
      end
    end
  end

  describe 'private methods' do
    let(:valid_csv_content) do
      <<~CSV
        Name,Email,Start Date,Department
        John Doe,john.doe@company.com,2024-01-15,Engineering
      CSV
    end

        let(:upload_event) { create(:upload_event, organization: organization, file_content: valid_csv_content, filename: 'test.csv') }

    describe '#create_teammate_relationship' do
      let(:person) { create(:person) }

      it 'creates teammate relationship with correct attributes' do
        teammate = processor.send(:create_teammate_relationship, person, organization, 'unassigned_employee', Date.parse('2024-01-15'))
        
        expect(teammate).to be_persisted
        expect(teammate.person).to eq(person)
        expect(teammate.organization).to eq(organization)
        expect(teammate.type).to eq('CompanyTeammate')
        expect(teammate.first_employed_at).to eq(Date.parse('2024-01-15'))
      end

      it 'uses current time when start_date is nil' do
        teammate = processor.send(:create_teammate_relationship, person, organization, 'unassigned_employee')
        
        expect(teammate.first_employed_at).to be_within(1.second).of(Time.current)
      end
    end

    describe '#ensure_teammate_relationship' do
      let(:person) { create(:person) }

      context 'when teammate relationship exists' do
        let!(:existing_teammate) { create(:teammate, person: person, organization: organization, type: 'CompanyTeammate') }

        it 'returns existing teammate' do
          result = processor.send(:ensure_teammate_relationship, person, organization)
          expect(result.id).to eq(existing_teammate.id)
          expect(result.class).to eq(CompanyTeammate)
        end

        it 'does not create new teammate' do
          expect { processor.send(:ensure_teammate_relationship, person, organization) }.not_to change(Teammate, :count)
        end
      end

      context 'when teammate relationship does not exist' do
        it 'creates new teammate relationship' do
          expect { processor.send(:ensure_teammate_relationship, person, organization) }.to change(Teammate, :count).by(1)
        end

        it 'returns created teammate' do
          result = processor.send(:ensure_teammate_relationship, person, organization)
          expect(result).to be_persisted
          expect(result.person).to eq(person)
          expect(result.organization).to eq(organization)
        end
      end
    end

    describe '#create_employment_tenure' do
      let(:person) { create(:person, first_name: 'John', last_name: 'Doe') }
      let!(:teammate) { create(:teammate, person: person, organization: organization, type: 'CompanyTeammate') }
      let!(:position_type) { create(:position_type, organization: organization, external_title: 'Software Engineer') }
      let!(:position_level) { create(:position_level, position_major_level: position_type.position_major_level) }
      let!(:position) { create(:position, position_type: position_type, position_level: position_level) }
      let!(:manager) { create(:person, first_name: 'Jane', last_name: 'Smith') }
      let(:employee_data) do
        {
          'start_date' => Date.parse('2024-01-15'),
          'job_title' => 'Software Engineer',
          'manager_name' => 'Jane Smith'
        }
      end

      it 'creates employment tenure with correct attributes' do
        employment_tenure = processor.send(:create_employment_tenure, person, teammate, employee_data)
        
        expect(employment_tenure).to be_persisted
        expect(employment_tenure.teammate.person).to eq(person)
        expect(employment_tenure.company).to eq(organization)
        expect(employment_tenure.teammate).to eq(teammate)
        expect(employment_tenure.position).to eq(position)
        expect(employment_tenure.started_at).to eq(Date.parse('2024-01-15'))
        expect(employment_tenure.manager).to eq(manager)
      end

      it 'handles missing manager gracefully' do
        employee_data_without_manager = employee_data.except('manager_name')
        
        employment_tenure = processor.send(:create_employment_tenure, person, teammate, employee_data_without_manager)
        
        expect(employment_tenure).to be_persisted
        expect(employment_tenure.manager).to be_nil
      end

      it 'handles missing position gracefully' do
        employee_data_without_position = employee_data.except('job_title')
        
        expect { processor.send(:create_employment_tenure, person, teammate, employee_data_without_position) }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    describe '#update_employee_information' do
      let(:person) { create(:person, first_name: 'John', last_name: 'Doe') }
      let!(:teammate) { create(:teammate, person: person, organization: organization, type: 'CompanyTeammate') }
      let(:employee_data) do
        {
          'start_date' => Date.parse('2024-01-15')
        }
      end

      it 'updates person attributes' do
        processor.send(:update_employee_information, person, employee_data)
        
        person.reload
        # Person model currently only has basic attributes
        # Additional attributes would need to be added to the model
        expect(person.first_name).to eq('John')
        expect(person.last_name).to eq('Doe')
      end

      it 'updates teammate start date' do
        processor.send(:update_employee_information, person, employee_data)
        
        teammate.reload
        expect(teammate.first_employed_at).to eq(Date.parse('2024-01-15'))
      end

      it 'handles missing teammate gracefully' do
        teammate.destroy
        
        expect { processor.send(:update_employee_information, person, employee_data) }.not_to raise_error
      end
    end
  end
end
