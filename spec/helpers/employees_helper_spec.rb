require 'rails_helper'

RSpec.describe EmployeesHelper, type: :helper do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:manager) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:current_teammate) { create(:teammate, person: create(:person), organization: organization) }
  
  # Note: We pass current_user explicitly to avoid needing to stub controller methods
  
  describe '#format_snapshot_changes' do
    context 'with employment changes' do
      let(:position_major_level) { create(:position_major_level) }
      let(:position_type1) { create(:position_type, organization: organization, position_major_level: position_major_level, external_title: 'Engineer 1') }
      let(:position_type2) { create(:position_type, organization: organization, position_major_level: position_major_level, external_title: 'Engineer 2') }
      let(:position_level1) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
      let(:position_level2) { create(:position_level, position_major_level: position_major_level, level: '1.2') }
      let(:position1) { create(:position, position_type: position_type1, position_level: position_level1) }
      let(:position2) { create(:position, position_type: position_type2, position_level: position_level2) }
      let(:employment_tenure) { create(:employment_tenure, teammate: teammate, company: organization, position: position1, started_at: 1.year.ago) }
      let(:snapshot) do
        create(:maap_snapshot,
          employee: person,
          created_by: manager,
          company: organization,
          change_type: 'position_tenure',
          maap_data: {
            'employment_tenure' => {
              'position_id' => position2.id,
              'manager_id' => manager.id,
              'started_at' => 6.months.ago.to_s,
              'seat_id' => nil
            },
            'assignments' => [],
            'milestones' => []
          }
        )
      end
      
      before do
        employment_tenure
      end
      
      it 'formats employment changes correctly' do
        changes = helper.format_snapshot_changes(snapshot, person, organization, current_user: current_teammate)
        
        expect(changes).to be_present
        expect(changes[:employment]).to be_present
        expect(changes[:employment].length).to be > 0
        
        position_change = changes[:employment].find { |c| c[:label] == 'Position' }
        expect(position_change).to be_present
        expect(position_change[:current]).to be_present
        expect(position_change[:proposed]).to be_present
        # Verify the change shows different positions
        expect(position_change[:current]).not_to eq(position_change[:proposed])
      end
    end
    
    context 'with assignment changes' do
      let(:assignment) { create(:assignment, company: organization) }
      let(:assignment_tenure) { create(:assignment_tenure, teammate: teammate, assignment: assignment, anticipated_energy_percentage: 20, started_at: 1.year.ago) }
      let(:snapshot) do
        create(:maap_snapshot,
          employee: person,
          created_by: manager,
          company: organization,
          change_type: 'assignment_management',
          maap_data: {
            'employment_tenure' => nil,
            'assignments' => [
              {
                'id' => assignment.id,
                'tenure' => {
                  'anticipated_energy_percentage' => 50,
                  'started_at' => 6.months.ago.to_s
                },
                'employee_check_in' => {
                  'actual_energy_percentage' => 30,
                  'employee_rating' => 'meeting',
                  'employee_completed_at' => Time.current,
                  'employee_private_notes' => 'Test notes',
                  'employee_personal_alignment' => 'love'
                },
                'manager_check_in' => nil,
                'official_check_in' => nil
              }
            ],
            'milestones' => []
          }
        )
      end
      
      before do
        assignment_tenure
      end
      
      it 'formats assignment changes correctly' do
        changes = helper.format_snapshot_changes(snapshot, person, organization, current_user: current_teammate)
        
        expect(changes).to be_present
        expect(changes[:assignments]).to be_present
        expect(changes[:assignments].length).to eq(1)
        
        assignment_change = changes[:assignments].first
        expect(assignment_change[:assignment_name]).to eq(assignment.title)
        expect(assignment_change[:changes].length).to be > 0
        
        energy_change = assignment_change[:changes].find { |c| c[:label] == 'Anticipated Energy' }
        expect(energy_change).to be_present
        expect(energy_change[:current]).to eq('20%')
        expect(energy_change[:proposed]).to eq('50%')
      end
    end
    
    context 'with milestone changes' do
      let(:ability) { create(:ability, organization: organization) }
      let(:milestone) { create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 1, attained_at: 1.year.ago) }
      let(:snapshot) do
        create(:maap_snapshot,
          employee: person,
          created_by: manager,
          company: organization,
          change_type: 'milestone_management',
          maap_data: {
            'employment_tenure' => nil,
            'assignments' => [],
            'milestones' => [
              {
                'ability_id' => ability.id,
                'milestone_level' => 2,
                'certified_by_id' => manager.id,
                'attained_at' => 6.months.ago.to_s,
                'teammate_id' => teammate.id
              }
            ]
          }
        )
      end
      
      before do
        milestone
      end
      
      it 'formats milestone changes correctly' do
        changes = helper.format_snapshot_changes(snapshot, person, organization, current_user: current_teammate)
        
        expect(changes).to be_present
        expect(changes[:milestones]).to be_present
        expect(changes[:milestones].length).to eq(1)
        
        milestone_change = changes[:milestones].first
        expect(milestone_change[:ability_name]).to eq(ability.name)
        expect(milestone_change[:changes].length).to be > 0
        
        level_change = milestone_change[:changes].find { |c| c[:label] == 'Milestone Level' }
        expect(level_change).to be_present
        expect(level_change[:current]).to eq('Level 1')
        expect(level_change[:proposed]).to eq('Level 2')
      end
    end
    
    context 'with no changes' do
      let(:snapshot) do
        create(:maap_snapshot,
          employee: person,
          created_by: manager,
          company: organization,
          change_type: 'exploration',
          maap_data: {
            'employment_tenure' => nil,
            'assignments' => [],
            'milestones' => []
          }
        )
      end
      
      it 'returns empty hash when there are no changes' do
        changes = helper.format_snapshot_changes(snapshot, person, organization, current_user: current_teammate)
        
        expect(changes).to be_a(Hash)
        expect(changes[:employment]).to be_nil
        expect(changes[:assignments]).to be_nil
        expect(changes[:milestones]).to be_nil
      end
    end
    
    context 'with nil snapshot' do
      it 'returns nil for nil snapshot' do
        changes = helper.format_snapshot_changes(nil, person, organization, current_user: current_teammate)
        expect(changes).to be_nil
      end
    end
    
    context 'with snapshot that has empty maap_data' do
      let(:snapshot) do
        # Use exploration trait which allows empty maap_data
        create(:maap_snapshot, :exploration,
          created_by: manager,
          company: organization
        )
      end
      
      it 'returns empty hash when maap_data is empty' do
        changes = helper.format_snapshot_changes(snapshot, person, organization, current_user: current_teammate)
        expect(changes).to be_a(Hash)
        expect(changes[:employment]).to be_nil
        expect(changes[:assignments]).to be_nil
        expect(changes[:milestones]).to be_nil
      end
    end
  end
end

