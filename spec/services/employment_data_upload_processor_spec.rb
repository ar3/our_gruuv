require 'rails_helper'

RSpec.describe EmploymentDataUploadProcessor do
  let(:organization) { create(:organization) }
  let(:person) { create(:person, current_organization: organization) }
  let(:upload_event) { create(:upload_event, creator: person, initiator: person) }
  let(:processor) { described_class.new(upload_event, organization) }

  before do
    # Set up preview actions with test data
    upload_event.update!(
      preview_actions: {
        'people' => [
          { 'name' => 'Test Person 1', 'email' => 'test1@example.com', 'row' => 2 },
          { 'name' => 'Test Person 2', 'email' => 'test2@example.com', 'row' => 3 }
        ],
        'assignments' => [
          { 'title' => 'Test Assignment 1', 'tagline' => 'Test description 1', 'row' => 2 },
          { 'title' => 'Test Assignment 2', 'tagline' => 'Test description 2', 'row' => 3 }
        ],
        'assignment_tenures' => [
          { 'anticipated_energy_percentage' => 80, 'started_at' => Date.new(2024, 1, 1), 'row' => 2 }
        ],
        'assignment_check_ins' => [
          { 
            'check_in_started_on' => Date.new(2024, 1, 15),
            'manager_private_notes' => 'Test notes',
            'row' => 2
          }
        ],
        'external_references' => [
          { 
            'assignment_name' => 'Test Assignment 1 [https://test.com/job]',
            'url' => 'https://test.com/job',
            'row' => 2
          }
        ]
      }
    )
  end

  describe '#initialize' do
    it 'sets upload_event, organization, and results' do
      expect(processor.upload_event).to eq(upload_event)
      expect(processor.organization).to eq(organization)
      expect(processor.results).to eq({ successes: [], failures: [] })
    end
  end

  describe '#process' do
    context 'when upload event cannot be processed' do
      before do
        upload_event.update!(status: 'completed')
      end

      it 'returns false without processing' do
        expect(processor.process).to be false
        expect(processor.results[:successes]).to be_empty
        expect(processor.results[:failures]).to be_empty
      end
    end

    context 'when upload event can be processed' do
      it 'marks upload as processing and then completed' do
        expect(upload_event).to receive(:mark_as_processing!)
        expect(upload_event).to receive(:mark_as_completed!).with(processor.results)
        
        processor.process
      end

      it 'processes all data sections' do
        expect(processor).to receive(:process_people)
        expect(processor).to receive(:process_assignments)
        expect(processor).to receive(:process_assignment_tenures)
        expect(processor).to receive(:process_assignment_check_ins)
        expect(processor).to receive(:process_external_references)
        
        processor.process
      end

      it 'returns true on successful processing' do
        expect(processor.process).to be true
      end
    end

    context 'when an error occurs during processing' do
      before do
        allow(processor).to receive(:process_people).and_raise('Something went wrong')
      end

      it 'marks upload as failed with error message' do
        expect(upload_event).to receive(:mark_as_failed!).with('Something went wrong')
        
        processor.process
      end

      it 'returns false on error' do
        expect(processor.process).to be false
      end
    end
  end

  describe 'private methods' do
    describe '#process_people' do
      it 'creates new people and records successes' do
        expect { processor.send(:process_people) }.to change(Person, :count).by(2)
        
        expect(processor.results[:successes].length).to eq(2)
        expect(processor.results[:successes].first[:type]).to eq('person')
        expect(processor.results[:successes].first[:action]).to eq('created')
      end

      it 'finds existing people by email' do
        existing_person = create(:person, email: 'test1@example.com')
        
        expect { processor.send(:process_people) }.to change(Person, :count).by(1)
        
        success = processor.results[:successes].find { |s| s[:name] == 'Test Person 1' }
        expect(success[:action]).to eq('found')
        expect(success[:id]).to eq(existing_person.id)
      end

      it 'handles errors gracefully' do
        allow(Person).to receive(:create!).and_raise('Validation failed')
        
        processor.send(:process_people)
        
        expect(processor.results[:failures].length).to eq(2)
        expect(processor.results[:failures].first[:type]).to eq('person')
        expect(processor.results[:failures].first[:error]).to eq('Validation failed')
      end
    end

    describe '#process_assignments' do
      it 'creates new assignments and records successes' do
        expect { processor.send(:process_assignments) }.to change(Assignment, :count).by(2)
        
        expect(processor.results[:successes].length).to eq(2)
        expect(processor.results[:successes].first[:type]).to eq('assignment')
        expect(processor.results[:successes].first[:action]).to eq('created')
      end

      it 'finds existing assignments by title' do
        existing_assignment = create(:assignment, title: 'Test Assignment 1', company: organization)
        
        expect { processor.send(:process_assignments) }.to change(Assignment, :count).by(1)
        
        success = processor.results[:successes].find { |s| s[:title] == 'Test Assignment 1' }
        expect(success[:action]).to eq('found')
        expect(success[:id]).to eq(existing_assignment.id)
      end
    end

    describe '#process_assignment_tenures' do
      it 'creates new tenures and records successes' do
        # First create the people and assignments needed for the tenure
        processor.send(:process_people)
        processor.send(:process_assignments)
        
        expect { processor.send(:process_assignment_tenures) }.to change(AssignmentTenure, :count).by(1)
        
        tenure_successes = processor.results[:successes].select { |s| s[:type] == 'assignment_tenure' }
        expect(tenure_successes.length).to eq(1)
        expect(tenure_successes.first[:action]).to eq('created')
      end

      it 'finds existing tenures' do
        # First create the people and assignments needed for the tenure
        processor.send(:process_people)
        processor.send(:process_assignment_tenures)
        
        # Create an existing tenure with the same data
        person = Person.find_by(email: 'test1@example.com')
        assignment = Assignment.find_by(title: 'Test Assignment 1')
        existing_tenure = create(:assignment_tenure, 
          person: person, 
          assignment: assignment, 
          started_at: Date.new(2024, 1, 1)
        )
        
        # Clear the results to test just the tenure processing
        processor.instance_variable_set(:@results, { successes: [], failures: [] })
        
        expect { processor.send(:process_assignment_tenures) }.not_to change(AssignmentTenure, :count)
        
        tenure_successes = processor.results[:successes].select { |s| s[:type] == 'assignment_tenure' }
        expect(tenure_successes.length).to eq(1)
        expect(tenure_successes.first[:action]).to eq('found')
        expect(tenure_successes.first[:id]).to eq(existing_tenure.id)
      end
    end

    describe '#process_assignment_check_ins' do
      it 'creates new check-ins and records successes' do
        # First create the people, assignments, and tenures needed for the check-in
        processor.send(:process_people)
        processor.send(:process_assignments)
        processor.send(:process_assignment_tenures)
        
        expect { processor.send(:process_assignment_check_ins) }.to change(AssignmentCheckIn, :count).by(1)
        
        check_in_successes = processor.results[:successes].select { |s| s[:type] == 'assignment_check_in' }
        expect(check_in_successes.length).to eq(1)
        expect(check_in_successes.first[:action]).to eq('created')
      end
    end

    describe '#process_external_references' do
      let!(:assignment) { create(:assignment, title: 'Test Assignment 1', company: organization) }

      before do
        allow(processor).to receive(:find_assignment_by_name).and_return(assignment)
      end

      it 'creates new external references and records successes' do
        expect { processor.send(:process_external_references) }.to change(ExternalReference, :count).by(1)
        
        expect(processor.results[:successes].length).to eq(1)
        expect(processor.results[:successes].first[:type]).to eq('external_reference')
        expect(processor.results[:successes].first[:action]).to eq('created')
      end

      it 'finds existing external references' do
        existing_ref = create(:external_reference, 
          referable: assignment, 
          reference_type: 'published',
          url: 'https://test.com/job'
        )
        
        expect { processor.send(:process_external_references) }.not_to change(ExternalReference, :count)
        
        success = processor.results[:successes].first
        expect(success[:action]).to eq('found')
        expect(success[:id]).to eq(existing_ref.id)
      end
    end

    describe '#find_or_create_person' do
      it 'finds existing person by email' do
        existing_person = create(:person, email: 'test1@example.com')
        
        result, was_created = processor.send(:find_or_create_person, { email: 'test1@example.com' })
        
        expect(result).to eq(existing_person)
        expect(was_created).to be false
      end

      it 'finds existing person by name' do
        existing_person = create(:person, first_name: 'Test Person', last_name: '1')
        
        result, was_created = processor.send(:find_or_create_person, { name: 'Test Person 1' })
        
        expect(result).to eq(existing_person)
        expect(was_created).to be false
      end

      it 'creates new person when not found' do
        expect { 
          processor.send(:find_or_create_person, { name: 'New Person', email: 'new@example.com' })
        }.to change(Person, :count).by(1)
        
        result, was_created = processor.send(:find_or_create_person, { name: 'Another Person', email: 'another@example.com' })
        expect(was_created).to be true
      end
    end

    describe '#find_or_create_assignment' do
      it 'finds existing assignment by title' do
        existing_assignment = create(:assignment, title: 'Test Assignment 1', company: organization)
        
        result, was_created = processor.send(:find_or_create_assignment, { title: 'Test Assignment 1' })
        
        expect(result).to eq(existing_assignment)
        expect(was_created).to be false
      end

      it 'creates new assignment when not found' do
        expect { 
          processor.send(:find_or_create_assignment, { title: 'New Assignment', tagline: 'Test description' })
        }.to change(Assignment, :count).by(1)
        
        result, was_created = processor.send(:find_or_create_assignment, { title: 'Another Assignment', tagline: 'Another description' })
        expect(was_created).to be true
      end
    end

    describe '#find_assignment_by_name' do
      it 'finds assignment by name with URL removed' do
        assignment = create(:assignment, title: 'Test Assignment 1', company: organization)
        
        result = processor.send(:find_assignment_by_name, 'Test Assignment 1 [https://test.com/job]')
        
        expect(result).to eq(assignment)
      end

      it 'handles names without URLs' do
        assignment = create(:assignment, title: 'Test Assignment 1', company: organization)
        
        result = processor.send(:find_assignment_by_name, 'Test Assignment 1')
        
        expect(result).to eq(assignment)
      end
    end
  end
end
