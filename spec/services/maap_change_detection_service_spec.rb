require 'rails_helper'

RSpec.describe MaapChangeDetectionService, type: :service do
  let(:person) { create(:person) }
  let(:assignment1) { create(:assignment) }
  let(:assignment2) { create(:assignment) }
  let(:assignment3) { create(:assignment) }
  let(:maap_snapshot) { create(:maap_snapshot, employee: person) }
  let(:service) { described_class.new(person: person, maap_snapshot: maap_snapshot) }

  describe '#change_counts' do
    context 'when there are no changes' do
      it 'returns zero counts for all categories' do
        counts = service.change_counts
        
        expect(counts[:employment]).to eq(0)
        expect(counts[:assignments]).to eq(0)
        expect(counts[:milestones]).to eq(0)
        expect(counts[:aspirations]).to eq(0)
      end
    end

    context 'when there are assignment changes' do
      before do
        # Create active tenure for assignment1
        create(:assignment_tenure, 
          person: person, 
          assignment: assignment1, 
          anticipated_energy_percentage: 25,
          started_at: 1.month.ago,
          ended_at: nil)

        # Create inactive tenure for assignment2
        create(:assignment_tenure,
          person: person,
          assignment: assignment2,
          anticipated_energy_percentage: 30,
          started_at: 2.months.ago,
          ended_at: 1.week.ago)

        # Update snapshot with changes
        maap_snapshot.update!(
          maap_data: {
            'assignments' => [
              {
                'id' => assignment1.id,
                'tenure' => {
                  'anticipated_energy_percentage' => 20, # Changed from 25 to 20
                  'started_at' => 1.month.ago.to_s
                },
                'employee_check_in' => {
                  'actual_energy_percentage' => 20,
                  'employee_rating' => 'meeting',
                  'personal_alignment' => 'aligned',
                  'employee_private_notes' => 'Test notes',
                  'employee_completed_at' => Time.current.to_s
                }
              },
              {
                'id' => assignment2.id,
                'tenure' => {
                  'anticipated_energy_percentage' => 0, # Ending tenure (was 30%)
                  'started_at' => 2.months.ago.to_s
                }
              },
              {
                'id' => assignment3.id,
                'tenure' => {
                  'anticipated_energy_percentage' => 15, # New tenure
                  'started_at' => Date.current.to_s
                }
              }
            ]
          }
        )
      end

      it 'returns correct assignment change count' do
        counts = service.change_counts
        
        expect(counts[:assignments]).to eq(2) # assignment1 (energy change), assignment3 (new tenure)
        # assignment2 is not counted because proposing 0% with no active tenure is not a change
      end
    end
  end

  describe '#detailed_changes' do
    context 'when there are assignment changes' do
      before do
        # Create active tenure for assignment1
        create(:assignment_tenure, 
          person: person, 
          assignment: assignment1, 
          anticipated_energy_percentage: 25,
          started_at: 1.month.ago,
          ended_at: nil)

        # Create inactive tenure for assignment2
        create(:assignment_tenure,
          person: person,
          assignment: assignment2,
          anticipated_energy_percentage: 30,
          started_at: 2.months.ago,
          ended_at: 1.week.ago)

        # Update snapshot with changes
        maap_snapshot.update!(
          maap_data: {
            'assignments' => [
              {
                'id' => assignment1.id,
                'tenure' => {
                  'anticipated_energy_percentage' => 20, # Changed from 25 to 20
                  'started_at' => 1.month.ago.to_s
                },
                'employee_check_in' => {
                  'actual_energy_percentage' => 20,
                  'employee_rating' => 'meeting',
                  'personal_alignment' => 'aligned',
                  'employee_private_notes' => 'Test notes',
                  'employee_completed_at' => Time.current.to_s
                }
              },
              {
                'id' => assignment2.id,
                'tenure' => {
                  'anticipated_energy_percentage' => 0, # Ending tenure (was 30%)
                  'started_at' => 2.months.ago.to_s
                }
              },
              {
                'id' => assignment3.id,
                'tenure' => {
                  'anticipated_energy_percentage' => 15, # New tenure
                  'started_at' => Date.current.to_s
                }
              }
            ]
          }
        )
      end

      it 'returns detailed assignment changes' do
        details = service.detailed_changes
        assignment_details = details[:assignments]

        expect(assignment_details[:has_changes]).to be true
        expect(assignment_details[:details].count).to eq(2)

        # Check assignment1 changes (energy change + new check-in)
        assignment1_changes = assignment_details[:details].find { |a| a[:assignment_id] == assignment1.id }
        expect(assignment1_changes).to be_present
        expect(assignment1_changes[:changes]).to include(
          hash_including(field: 'anticipated_energy_percentage', current: 25, proposed: 20)
        )
        expect(assignment1_changes[:changes]).to include(
          hash_including(field: 'new_employee_check_in', current: 'none', proposed: 'new check-in')
        )

        # assignment2 is not included because proposing 0% with no active tenure is not a change

        # Check assignment3 changes (new tenure)
        assignment3_changes = assignment_details[:details].find { |a| a[:assignment_id] == assignment3.id }
        expect(assignment3_changes).to be_present
        expect(assignment3_changes[:changes]).to include(
          hash_including(field: 'new_tenure', current: 'none', proposed: 15)
        )
      end
    end

    context 'when there are no changes' do
      before do
        # Create active tenure
        create(:assignment_tenure, 
          person: person, 
          assignment: assignment1, 
          anticipated_energy_percentage: 25,
          started_at: 1.month.ago,
          ended_at: nil)

        # Update snapshot with same values
        maap_snapshot.update!(
          maap_data: {
            'assignments' => [
              {
                'id' => assignment1.id,
                'tenure' => {
                  'anticipated_energy_percentage' => 25, # Same as current
                  'started_at' => 1.month.ago.to_s
                }
              }
            ]
          }
        )
      end

      it 'returns no assignment changes' do
        details = service.detailed_changes
        assignment_details = details[:assignments]

        expect(assignment_details[:has_changes]).to be false
        expect(assignment_details[:details]).to be_empty
      end
    end
  end

  describe 'assignment change detection edge cases' do
    context 'when assignment has no active tenure but snapshot proposes 0%' do
      before do
        # Create inactive tenure
        create(:assignment_tenure,
          person: person,
          assignment: assignment1,
          anticipated_energy_percentage: 30,
          started_at: 2.months.ago,
          ended_at: 1.week.ago)

        # Update snapshot with 0% (confirming current state)
        maap_snapshot.update!(
          maap_data: {
            'assignments' => [
              {
                'id' => assignment1.id,
                'tenure' => {
                  'anticipated_energy_percentage' => 0,
                  'started_at' => 2.months.ago.to_s
                }
              }
            ]
          }
        )
      end

      it 'detects no change (confirming current state)' do
        counts = service.change_counts
        expect(counts[:assignments]).to eq(0)

        details = service.detailed_changes
        assignment_details = details[:assignments]
        expect(assignment_details[:has_changes]).to be false
        expect(assignment_details[:details]).to be_empty
      end
    end

    context 'when assignment has no tenure history but snapshot proposes new tenure' do
      before do
        # No existing tenure

        # Update snapshot with new tenure
        maap_snapshot.update!(
          maap_data: {
            'assignments' => [
              {
                'id' => assignment1.id,
                'tenure' => {
                  'anticipated_energy_percentage' => 15,
                  'started_at' => Date.current.to_s
                }
              }
            ]
          }
        )
      end

      it 'detects new tenure change' do
        counts = service.change_counts
        expect(counts[:assignments]).to eq(1)

        details = service.detailed_changes
        assignment_details = details[:assignments]
        expect(assignment_details[:has_changes]).to be true
        expect(assignment_details[:details].count).to eq(1)
        
        change = assignment_details[:details].first
        expect(change[:changes]).to include(
          hash_including(field: 'new_tenure', current: 'none', proposed: 15)
        )
      end
    end

    context 'when assignment has no tenure history and snapshot proposes 0%' do
      before do
        # No existing tenure

        # Update snapshot with 0% (no change)
        maap_snapshot.update!(
          maap_data: {
            'assignments' => [
              {
                'id' => assignment1.id,
                'tenure' => {
                  'anticipated_energy_percentage' => 0,
                  'started_at' => Date.current.to_s
                }
              }
            ]
          }
        )
      end

      it 'detects no change' do
        counts = service.change_counts
        expect(counts[:assignments]).to eq(0)

        details = service.detailed_changes
        assignment_details = details[:assignments]
        expect(assignment_details[:has_changes]).to be false
      end
    end
  end

  describe 'check-in change detection' do
    context 'when there are check-in changes' do
      before do
        # Create active tenure
        create(:assignment_tenure, 
          person: person, 
          assignment: assignment1, 
          anticipated_energy_percentage: 25,
          started_at: 1.month.ago,
          ended_at: nil)

        # Create existing check-in
        create(:assignment_check_in,
          person: person,
          assignment: assignment1,
          actual_energy_percentage: 20,
          employee_rating: 'meeting',
          employee_personal_alignment: 'like',
          employee_private_notes: 'Old notes')

        # Update snapshot with check-in changes
        maap_snapshot.update!(
          maap_data: {
            'assignments' => [
              {
                'id' => assignment1.id,
                'tenure' => {
                  'anticipated_energy_percentage' => 25, # Same
                  'started_at' => 1.month.ago.to_s
                },
                'employee_check_in' => {
                  'actual_energy_percentage' => 25, # Changed from 20
                  'employee_rating' => 'exceeding', # Changed from meeting
                  'personal_alignment' => 'like', # Same
                  'employee_private_notes' => 'New notes', # Changed
                  'employee_completed_at' => Time.current.to_s # New completion
                }
              }
            ]
          }
        )
      end

      it 'detects check-in changes' do
        counts = service.change_counts
        expect(counts[:assignments]).to eq(1)

        details = service.detailed_changes
        assignment_details = details[:assignments]
        expect(assignment_details[:has_changes]).to be true
        
        change = assignment_details[:details].first
        expect(change[:changes]).to include(
          hash_including(field: 'employee_actual_energy', current: 20, proposed: 25)
        )
        expect(change[:changes]).to include(
          hash_including(field: 'employee_rating', current: 'meeting', proposed: 'exceeding')
        )
        expect(change[:changes]).to include(
          hash_including(field: 'employee_private_notes', current: 'Old notes', proposed: 'New notes')
        )
        expect(change[:changes]).to include(
          hash_including(field: 'employee_completion', current: false, proposed: true)
        )
      end
    end
  end
end
