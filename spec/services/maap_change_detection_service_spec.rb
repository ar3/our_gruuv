require 'rails_helper'

RSpec.describe MaapChangeDetectionService do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:manager) { create(:person) }
  let(:assignment) { create(:assignment, company: organization) }
  
  describe '#assignment_changes_count' do
    context 'with MaapSnapshot 122 scenario' do
      let(:snapshot) { create(:maap_snapshot, id: 122) }
      
      before do
        # Set up the exact scenario from MaapSnapshot 122
        snapshot.update!(
          employee: person,
          created_by: manager,
          company: organization,
          change_type: 'assignment_management',
          reason: 'Assignment updates',
          maap_data: {
            'assignments' => [
              {
                'id' => assignment.id,
                'tenure' => {
                  'started_at' => '2025-09-20',
                  'anticipated_energy_percentage' => 50
                },
                'manager_check_in' => {
                  'manager_rating' => 'working_to_meet',
                  'manager_completed_at' => nil,
                  'manager_private_notes' => '40-50\nworking\ncomplete',
                  'manager_completed_by_id' => nil
                },
                'employee_check_in' => {
                  'employee_rating' => 'working_to_meet',
                  'employee_completed_at' => '2025-09-29T00:15:44.283Z',
                  'employee_private_notes' => 'dsfdsafds',
                  'actual_energy_percentage' => 15,
                  'employee_personal_alignment' => 'love'
                },
                'official_check_in' => {
                  'shared_notes' => nil,
                  'finalized_by_id' => nil,
                  'official_rating' => nil,
                  'official_check_in_completed_at' => nil
                }
              }
            ],
            'employment_tenure' => {
              'seat_id' => nil,
              'manager_id' => manager.id,
              'started_at' => '2025-03-08T00:00:00.000Z',
              'position_id' => 8
            },
            'milestones' => [],
            'aspirations' => []
          }
        )
        
        # Create current state that differs from proposed state
        create(:assignment_tenure, 
               person: person, 
               assignment: assignment, 
               anticipated_energy_percentage: 40, # Different from proposed 50
               started_at: Date.parse('2025-09-20'))
        
        # Create current check-in that differs from proposed state
        create(:assignment_check_in,
               person: person,
               assignment: assignment,
               manager_rating: 'working_to_meet',
               manager_private_notes: '40-50\nworking\ncomplete',
               manager_completed_at: Time.current, # Different from proposed nil
               manager_completed_by: manager,
               # Set employee fields to match proposed values to avoid extra changes
               actual_energy_percentage: 15,
               employee_rating: 'working_to_meet',
               employee_personal_alignment: 'love',
               employee_private_notes: 'dsfdsafds',
               employee_completed_at: Time.parse('2025-09-29T00:15:44.283Z'),
               # Set official fields to match proposed values
               shared_notes: nil,
               official_rating: nil,
               official_check_in_completed_at: nil,
               finalized_by_id: nil)
      end
      
      it 'correctly counts assignment changes' do
        service = described_class.new(
          person: person, 
          maap_snapshot: snapshot, 
          current_user: manager
        )
        
        # This should detect changes in:
        # 1. anticipated_energy_percentage: 40 → 50
        # 2. manager_completion: true → false
        expect(service.change_counts[:assignments]).to eq(1)
      end
      
      it 'correctly identifies which assignment has changes' do
        service = described_class.new(
          person: person, 
          maap_snapshot: snapshot, 
          current_user: manager
        )
        
        expect(service.assignment_has_changes?(assignment)).to be true
      end
      
      it 'provides detailed change information' do
        service = described_class.new(
          person: person, 
          maap_snapshot: snapshot, 
          current_user: manager
        )
        
        details = service.detailed_changes[:assignments]
        expect(details[:has_changes]).to be true
        expect(details[:details].length).to eq(1)
        
        assignment_changes = details[:details].first
        expect(assignment_changes[:assignment_id]).to eq(assignment.id)
        expect(assignment_changes[:changes].length).to eq(2)
        
        # Check for specific changes
        change_fields = assignment_changes[:changes].map { |c| c[:field] }
        expect(change_fields).to include('anticipated_energy_percentage')
        expect(change_fields).to include('manager_completion')
      end
    end
  end
end