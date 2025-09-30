require 'rails_helper'

RSpec.describe MaapChangeDetectionService, type: :service do
  let(:organization) { create(:organization) }
  let(:person) { create(:person, current_organization: organization) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:maap_snapshot) { create(:maap_snapshot, created_by: person) }
  let(:service) { described_class.new(person: person, maap_snapshot: maap_snapshot, current_user: person) }

  describe '#assignment_has_changes?' do
    context 'when there are no changes' do
      let(:maap_snapshot) do
        create(:maap_snapshot, 
               created_by: person,
               maap_data: {
                 'assignments' => [
                   {
                     'id' => assignment.id,
                     'tenure' => {
                       'anticipated_energy_percentage' => 50,
                       'started_at' => '2025-01-01'
                     },
                     'employee_check_in' => {
                       'actual_energy_percentage' => 45,
                       'employee_rating' => 'meeting',
                       'employee_personal_alignment' => 'like',
                       'employee_private_notes' => 'Great work',
                       'employee_completed_at' => '2025-01-15T10:00:00Z'
                     },
                     'manager_check_in' => {
                       'manager_rating' => 'meeting',
                       'manager_private_notes' => 'Good progress',
                       'manager_completed_at' => '2025-01-15T11:00:00Z',
                       'manager_completed_by_id' => person.id
                     }
                   }
                 ]
               })
      end

      before do
        # Create matching current data
        create(:assignment_tenure, 
               person: person, 
               assignment: assignment,
               anticipated_energy_percentage: 50,
               started_at: Date.parse('2025-01-01'))
        
        create(:assignment_check_in,
               person: person,
               assignment: assignment,
               actual_energy_percentage: 45,
               employee_rating: 'meeting',
               employee_personal_alignment: 'like',
               employee_private_notes: 'Great work',
               employee_completed_at: Time.parse('2025-01-15T10:00:00Z'),
               manager_rating: 'meeting',
               manager_private_notes: 'Good progress',
               manager_completed_at: Time.parse('2025-01-15T11:00:00Z'),
               manager_completed_by: person)
      end

      it 'returns false when all fields match exactly' do
        expect(service.assignment_has_changes?(assignment)).to be false
      end
    end

    context 'when there are employee check-in changes' do
      let(:maap_snapshot) do
        create(:maap_snapshot,
               created_by: person,
               maap_data: {
                 'assignments' => [
                   {
                     'id' => assignment.id,
                     'tenure' => {
                       'anticipated_energy_percentage' => 50,
                       'started_at' => '2025-01-01'
                     },
                     'employee_check_in' => {
                       'actual_energy_percentage' => 40,  # Changed from 45
                       'employee_rating' => 'exceeding',   # Changed from 'meeting'
                       'employee_personal_alignment' => 'love',  # Changed from 'like'
                       'employee_private_notes' => 'Updated notes',  # Changed
                       'employee_completed_at' => '2025-01-15T10:00:00Z'
                     }
                   }
                 ]
               })
      end

      before do
        # Create current data with different values
        create(:assignment_tenure,
               person: person,
               assignment: assignment,
               anticipated_energy_percentage: 50,
               started_at: Date.parse('2025-01-01'))
        
        create(:assignment_check_in,
               person: person,
               assignment: assignment,
               actual_energy_percentage: 45,
               employee_rating: 'meeting',
               employee_personal_alignment: 'like',
               employee_private_notes: 'Great work',
               employee_completed_at: Time.parse('2025-01-15T10:00:00Z'))
      end

      it 'returns true when employee fields have changed' do
        expect(service.assignment_has_changes?(assignment)).to be true
      end

      it 'detects specific field changes correctly' do
        detailed_changes = service.detailed_changes
        assignment_changes = detailed_changes[:assignments][:details].find { |change| change[:assignment_id] == assignment.id }
        
        expect(assignment_changes).to be_present
        change_fields = assignment_changes[:changes].map { |change| change[:field] }
        
        expect(change_fields).to include('employee_actual_energy')
        expect(change_fields).to include('employee_rating')
        expect(change_fields).to include('employee_personal_alignment')
        expect(change_fields).to include('employee_private_notes')
      end
    end

    context 'when there are manager check-in changes' do
      let(:maap_snapshot) do
        create(:maap_snapshot,
               created_by: person,
               maap_data: {
                 'assignments' => [
                   {
                     'id' => assignment.id,
                     'tenure' => {
                       'anticipated_energy_percentage' => 50,
                       'started_at' => '2025-01-01'
                     },
                     'manager_check_in' => {
                       'manager_rating' => 'exceeding',  # Changed
                       'manager_private_notes' => 'Updated manager notes',  # Changed
                       'manager_completed_at' => '2025-01-15T11:00:00Z'
                     }
                   }
                 ]
               })
      end

      before do
        create(:assignment_tenure,
               person: person,
               assignment: assignment,
               anticipated_energy_percentage: 50,
               started_at: Date.parse('2025-01-01'))
        
        create(:assignment_check_in,
               person: person,
               assignment: assignment,
               manager_rating: 'meeting',
               manager_private_notes: 'Good progress',
               manager_completed_at: Time.parse('2025-01-15T11:00:00Z'))
      end

      it 'returns true when manager fields have changed' do
        expect(service.assignment_has_changes?(assignment)).to be true
      end

      it 'detects manager field changes correctly' do
        detailed_changes = service.detailed_changes
        assignment_changes = detailed_changes[:assignments][:details].find { |change| change[:assignment_id] == assignment.id }
        
        expect(assignment_changes).to be_present
        change_fields = assignment_changes[:changes].map { |change| change[:field] }
        
        expect(change_fields).to include('manager_rating')
        expect(change_fields).to include('manager_private_notes')
      end
    end

    context 'when there are tenure changes' do
      let(:maap_snapshot) do
        create(:maap_snapshot,
               created_by: person,
               maap_data: {
                 'assignments' => [
                   {
                     'id' => assignment.id,
                     'tenure' => {
                       'anticipated_energy_percentage' => 60,  # Changed from 50
                       'started_at' => '2025-01-02'  # Changed from '2025-01-01'
                     }
                   }
                 ]
               })
      end

      before do
        create(:assignment_tenure,
               person: person,
               assignment: assignment,
               anticipated_energy_percentage: 50,
               started_at: Date.parse('2025-01-01'))
      end

      it 'returns true when tenure fields have changed' do
        expect(service.assignment_has_changes?(assignment)).to be true
      end

      it 'detects tenure field changes correctly' do
        detailed_changes = service.detailed_changes
        assignment_changes = detailed_changes[:assignments][:details].find { |change| change[:assignment_id] == assignment.id }
        
        expect(assignment_changes).to be_present
        change_fields = assignment_changes[:changes].map { |change| change[:field] }
        
        expect(change_fields).to include('anticipated_energy_percentage')
        expect(change_fields).to include('started_at')
      end
    end
  end

  describe 'field name consistency' do
    context 'employee_personal_alignment field' do
      let(:maap_snapshot) do
        create(:maap_snapshot,
               created_by: person,
               maap_data: {
                 'assignments' => [
                   {
                     'id' => assignment.id,
                     'tenure' => {
                       'anticipated_energy_percentage' => 50,
                       'started_at' => '2025-01-01'
                     },
                     'employee_check_in' => {
                       'employee_personal_alignment' => 'love'  # Using correct field name
                     }
                   }
                 ]
               })
      end

      before do
        create(:assignment_tenure,
               person: person,
               assignment: assignment,
               anticipated_energy_percentage: 50,
               started_at: Date.parse('2025-01-01'))
        
        create(:assignment_check_in,
               person: person,
               assignment: assignment,
               employee_personal_alignment: 'like')
      end

      it 'correctly compares employee_personal_alignment field' do
        expect(service.assignment_has_changes?(assignment)).to be true
      end

      it 'uses consistent field names in detailed changes' do
        detailed_changes = service.detailed_changes
        assignment_changes = detailed_changes[:assignments][:details].find { |change| change[:assignment_id] == assignment.id }
        
        expect(assignment_changes).to be_present
        personal_alignment_change = assignment_changes[:changes].find { |change| change[:field] == 'employee_personal_alignment' }
        
        expect(personal_alignment_change).to be_present
        expect(personal_alignment_change[:current]).to eq('like')
        expect(personal_alignment_change[:proposed]).to eq('love')
      end
    end
  end

  describe '#change_counts' do
    let(:maap_snapshot) do
      create(:maap_snapshot,
             created_by: person,
             maap_data: {
               'assignments' => [
                 {
                   'id' => assignment.id,
                   'tenure' => {
                     'anticipated_energy_percentage' => 60,
                     'started_at' => '2025-01-01'
                   }
                 }
               ]
             })
    end

    before do
      create(:assignment_tenure,
             person: person,
             assignment: assignment,
             anticipated_energy_percentage: 50,
             started_at: Date.parse('2025-01-01'))
    end

    it 'returns correct count of assignment changes' do
      counts = service.change_counts
      expect(counts[:assignments]).to eq(1)
    end
  end
end