require 'rails_helper'

RSpec.describe InitialMaapSnapshotService, type: :service do
  let!(:company) { create(:organization, :company) }
  let!(:person) { create(:person) }
  let!(:company_teammate) { create(:company_teammate, person: person, organization: company) }
  let!(:position_major_level) { create(:position_major_level) }
  let!(:title) { create(:title, company: company, position_major_level: position_major_level) }
  let!(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let!(:position) { create(:position, title: title, position_level: position_level) }
  let!(:assignment1) { create(:assignment, company: company, title: 'Assignment 1') }
  let!(:assignment2) { create(:assignment, company: company, title: 'Assignment 2') }
  let!(:employment_tenure) do
    create(:employment_tenure,
      teammate: company_teammate,
      company: company,
      position: position,
      started_at: 1.month.ago,
      ended_at: nil
    )
  end

  describe '#create_initial_snapshot' do
    context 'when all prerequisites are met' do
      before do
        # Create position_assignments for the employment_tenure's position
        actual_position = employment_tenure.reload.position
        create(:position_assignment,
          position: actual_position,
          assignment: assignment1,
          assignment_type: 'required',
          min_estimated_energy: 20,
          max_estimated_energy: 30
        )
        create(:position_assignment,
          position: actual_position,
          assignment: assignment2,
          assignment_type: 'required',
          min_estimated_energy: 10,
          max_estimated_energy: 20
        )
      end

      it 'creates an initial MAAP snapshot' do
        service = described_class.new(company_teammate: company_teammate)
        
        expect {
          result = service.create_initial_snapshot
          puts "DEBUG: Result = #{result.inspect}" unless result[:success]
          expect(result[:success]).to be true
          expect(result[:snapshot]).to be_a(MaapSnapshot)
        }.to change { MaapSnapshot.count }.by(1)
      end

      it 'sets correct attributes on the snapshot' do
        service = described_class.new(company_teammate: company_teammate)
        result = service.create_initial_snapshot

        snapshot = result[:snapshot]
        expect(snapshot.employee_company_teammate).to eq(company_teammate)
        expect(snapshot.company).to eq(company)
        expect(snapshot.change_type).to eq('assignment_management')
        expect(snapshot.reason).to eq('Initial expectation')
        expect(snapshot.creator_company_teammate.person.id).to eq(-1)
        expect(snapshot.creator_company_teammate.person.first_name).to eq('OG')
        expect(snapshot.creator_company_teammate.person.last_name).to eq('Automation')
      end

      it 'includes required assignments in maap_data with correct energy percentages' do
        service = described_class.new(company_teammate: company_teammate)
        result = service.create_initial_snapshot

        snapshot = result[:snapshot]
        assignments_data = snapshot.maap_data['assignments']
        
        expect(assignments_data.length).to eq(2)
        
        # Check first assignment (20-30% range, average = 25%)
        assignment1_data = assignments_data.find { |a| a['assignment_id'] == assignment1.id }
        expect(assignment1_data).to be_present
        expect(assignment1_data['anticipated_energy_percentage']).to eq(25)
        expect(assignment1_data['rated_assignment']).to eq({})

        # Check second assignment (10-20% range, average = 15%)
        assignment2_data = assignments_data.find { |a| a['assignment_id'] == assignment2.id }
        expect(assignment2_data).to be_present
        expect(assignment2_data['anticipated_energy_percentage']).to eq(15)
        expect(assignment2_data['rated_assignment']).to eq({})
      end

      it 'includes position data in maap_data' do
        service = described_class.new(company_teammate: company_teammate)
        result = service.create_initial_snapshot

        snapshot = result[:snapshot]
        position_data = snapshot.maap_data['position']
        actual_position = employment_tenure.reload.position
        
        expect(position_data).to be_present
        expect(position_data['position_id']).to eq(actual_position.id)
      end

      it 'handles assignments with only min energy' do
        # Find the position_assignment for assignment1 and update it
        actual_position = employment_tenure.reload.position
        pa1 = PositionAssignment.find_by(position: actual_position, assignment: assignment1)
        pa1.update!(max_estimated_energy: nil)
        
        service = described_class.new(company_teammate: company_teammate)
        result = service.create_initial_snapshot

        snapshot = result[:snapshot]
        assignment1_data = snapshot.maap_data['assignments'].find { |a| a['assignment_id'] == assignment1.id }
        expect(assignment1_data['anticipated_energy_percentage']).to eq(20) # Uses min when max is nil
      end

      it 'handles assignments with only max energy' do
        # Find the position_assignment for assignment1 and update it
        actual_position = employment_tenure.reload.position
        pa1 = PositionAssignment.find_by(position: actual_position, assignment: assignment1)
        pa1.update!(min_estimated_energy: nil)
        
        service = described_class.new(company_teammate: company_teammate)
        result = service.create_initial_snapshot

        snapshot = result[:snapshot]
        assignment1_data = snapshot.maap_data['assignments'].find { |a| a['assignment_id'] == assignment1.id }
        expect(assignment1_data['anticipated_energy_percentage']).to eq(30) # Uses max when min is nil
      end

      it 'is idempotent - returns existing snapshot on second call' do
        service = described_class.new(company_teammate: company_teammate)
        
        first_result = service.create_initial_snapshot
        first_snapshot = first_result[:snapshot]
        
        second_result = service.create_initial_snapshot
        expect(second_result[:success]).to be true
        expect(second_result[:snapshot]).to eq(first_snapshot)
        expect(second_result[:message]).to eq('Initial snapshot already exists')
        
        # Should not create a duplicate
        expect(MaapSnapshot.count).to eq(1)
      end
    end

    context 'when company teammate already has MAAP snapshots' do
      before do
        create(:maap_snapshot, employee_company_teammate: company_teammate, company: company)
      end

      it 'returns failure with appropriate message' do
        service = described_class.new(company_teammate: company_teammate)
        result = service.create_initial_snapshot

        expect(result[:success]).to be false
        expect(result[:message]).to eq('Company teammate already has MAAP snapshots')
        expect(result[:snapshot]).to be_nil
      end

      it 'does not create a new snapshot' do
        # Snapshot already created in before block
        existing_count = MaapSnapshot.count
        
        service = described_class.new(company_teammate: company_teammate)
        service.create_initial_snapshot
        
        expect(MaapSnapshot.count).to eq(existing_count)
      end
    end

    context 'when company teammate has no active employment tenure' do
      before do
        employment_tenure.update!(ended_at: 1.week.ago)
      end

      it 'returns failure with appropriate message' do
        service = described_class.new(company_teammate: company_teammate)
        result = service.create_initial_snapshot

        expect(result[:success]).to be false
        expect(result[:message]).to eq('Company teammate has no active employment tenure')
        expect(result[:snapshot]).to be_nil
      end

      it 'does not create a snapshot' do
        service = described_class.new(company_teammate: company_teammate)
        
        expect {
          service.create_initial_snapshot
        }.not_to change { MaapSnapshot.count }
      end
    end

    context 'when position has no required assignments' do
      it 'returns failure with appropriate message' do
        service = described_class.new(company_teammate: company_teammate)
        result = service.create_initial_snapshot

        expect(result[:success]).to be false
        expect(result[:message]).to eq('Position has no required assignments')
        expect(result[:snapshot]).to be_nil
      end
    end

    context 'when required assignments are missing min/max energy values' do
      let!(:position_assignment1) do
        create(:position_assignment,
          position: position,
          assignment: assignment1,
          assignment_type: 'required',
          min_estimated_energy: nil,
          max_estimated_energy: nil
        )
      end
      let!(:position_assignment2) do
        create(:position_assignment,
          position: position,
          assignment: assignment2,
          assignment_type: 'required',
          min_estimated_energy: 10,
          max_estimated_energy: 20
        )
      end

      it 'returns failure with appropriate message listing missing assignments' do
        service = described_class.new(company_teammate: company_teammate)
        result = service.create_initial_snapshot

        expect(result[:success]).to be false
        expect(result[:message]).to include('One or more required position assignments missing min/max energy values')
        expect(result[:message]).to include('Assignment 1')
        expect(result[:snapshot]).to be_nil
      end

      it 'does not create a snapshot' do
        service = described_class.new(company_teammate: company_teammate)
        
        expect {
          service.create_initial_snapshot
        }.not_to change { MaapSnapshot.count }
      end
    end

    context 'when position has suggested assignments but no required assignments' do
      let!(:suggested_assignment) do
        create(:position_assignment,
          position: position,
          assignment: assignment1,
          assignment_type: 'suggested',
          min_estimated_energy: 10,
          max_estimated_energy: 20
        )
      end

      it 'returns failure with appropriate message' do
        service = described_class.new(company_teammate: company_teammate)
        result = service.create_initial_snapshot

        expect(result[:success]).to be false
        expect(result[:message]).to eq('Position has no required assignments')
        expect(result[:snapshot]).to be_nil
      end
    end

    describe 'OG Automation person creation' do
      let!(:position_assignment1) do
        create(:position_assignment,
          position: position,
          assignment: assignment1,
          assignment_type: 'required',
          min_estimated_energy: 20,
          max_estimated_energy: 30
        )
      end

      context 'when OG Automation person does not exist' do
        it 'creates OG Automation person with id = -1' do
          expect(Person.find_by(id: -1)).to be_nil
          
          service = described_class.new(company_teammate: company_teammate)
          service.create_initial_snapshot

          og_automation = Person.find(-1)
          expect(og_automation).to be_present
          expect(og_automation.first_name).to eq('OG')
          expect(og_automation.last_name).to eq('Automation')
          expect(og_automation.email).to eq('automation@og.local')
        end
      end

      context 'when OG Automation person already exists with id = -1' do
        let!(:existing_og) do
          Person.create!(
            id: -1,
            first_name: 'OG',
            last_name: 'Automation',
            email: 'automation@og.local'
          )
        end

        it 'uses existing OG Automation person' do
          service = described_class.new(company_teammate: company_teammate)
          result = service.create_initial_snapshot

          expect(result[:snapshot].created_by).to eq(existing_og)
        end
      end

      context 'when OG Automation person exists with different id' do
        let!(:existing_og) do
          Person.create!(
            first_name: 'OG',
            last_name: 'Automation',
            email: 'automation@og.local'
          )
        end

        it 'updates existing person to id = -1 and uses it' do
          original_id = existing_og.id
          expect(original_id).not_to eq(-1)
          
          service = described_class.new(company_teammate: company_teammate)
          result = service.create_initial_snapshot

          expect(Person.find_by(id: original_id)).to be_nil
          og_automation = Person.find(-1)
          expect(og_automation).to be_present
          expect(og_automation.email).to eq('automation@og.local')
          expect(result[:snapshot].created_by).to eq(og_automation)
        end
      end
    end

    context 'when position has both required and suggested assignments' do
      let!(:required_assignment) do
        create(:position_assignment,
          position: position,
          assignment: assignment1,
          assignment_type: 'required',
          min_estimated_energy: 20,
          max_estimated_energy: 30
        )
      end
      let!(:suggested_assignment) do
        create(:position_assignment,
          position: position,
          assignment: assignment2,
          assignment_type: 'suggested',
          min_estimated_energy: 10,
          max_estimated_energy: 20
        )
      end

      it 'only includes required assignments in the snapshot' do
        service = described_class.new(company_teammate: company_teammate)
        result = service.create_initial_snapshot

        snapshot = result[:snapshot]
        assignments_data = snapshot.maap_data['assignments']
        
        expect(assignments_data.length).to eq(1)
        expect(assignments_data.first['assignment_id']).to eq(assignment1.id)
        expect(assignments_data.map { |a| a['assignment_id'] }).not_to include(assignment2.id)
      end
    end
  end
end


