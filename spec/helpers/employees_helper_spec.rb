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
      let(:previous_snapshot) do
        create(:maap_snapshot,
          employee: person,
          created_by: manager,
          company: organization,
          change_type: 'position_tenure',
          created_at: 2.days.ago,
          maap_data: {
            'position' => {
              'position_id' => position1.id,
              'manager_id' => manager.id,
              'seat_id' => nil,
              'employment_type' => 'full_time',
              'rated_position' => {}
            },
            'assignments' => [],
            'abilities' => [],
            'aspirations' => []
          }
        )
      end
      let(:snapshot) do
        create(:maap_snapshot,
          employee: person,
          created_by: manager,
          company: organization,
          change_type: 'position_tenure',
          created_at: 1.day.ago,
          maap_data: {
            'position' => {
              'position_id' => position2.id,
              'manager_id' => manager.id,
              'seat_id' => nil,
              'employment_type' => 'full_time',
              'rated_position' => {
                'position_id' => position2.id,
                'manager_id' => manager.id,
                'seat_id' => nil,
                'employment_type' => 'full_time',
                'official_position_rating' => 2,
                'started_at' => 2.days.ago.iso8601,
                'ended_at' => 1.day.ago.iso8601
              }
            },
            'assignments' => [],
            'abilities' => [],
            'aspirations' => []
          }
        )
      end
      
      before do
        previous_snapshot
      end
      
      it 'formats employment changes correctly' do
        changes = helper.format_snapshot_changes(snapshot, person, organization, current_user: current_teammate, previous_snapshot: previous_snapshot)
        
        expect(changes).to be_present
        expect(changes[:employment]).to be_present
        expect(changes[:employment].length).to be > 0
        
        # Should detect changes in rated_position
        rated_position_change = changes[:employment].find { |c| c[:label] == 'Rated Position' }
        expect(rated_position_change).to be_present
        expect(rated_position_change[:current]).to be_present
        expect(rated_position_change[:proposed]).to be_present
        # Verify the change shows different positions
        expect(rated_position_change[:current]).not_to eq(rated_position_change[:proposed])
      end
    end
    
    context 'with assignment changes' do
      let(:assignment) { create(:assignment, company: organization) }
      let(:previous_snapshot) do
        create(:maap_snapshot,
          employee: person,
          created_by: manager,
          company: organization,
          change_type: 'assignment_management',
          created_at: 2.days.ago,
          maap_data: {
            'position' => nil,
            'assignments' => [
              {
                'assignment_id' => assignment.id,
                'anticipated_energy_percentage' => 20,
                'rated_assignment' => {}
              }
            ],
            'abilities' => [],
            'aspirations' => []
          }
        )
      end
      let(:snapshot) do
        create(:maap_snapshot,
          employee: person,
          created_by: manager,
          company: organization,
          change_type: 'assignment_management',
          created_at: 1.day.ago,
          maap_data: {
            'position' => nil,
            'assignments' => [
              {
                'assignment_id' => assignment.id,
                'anticipated_energy_percentage' => 50,
                'rated_assignment' => {}
              }
            ],
            'abilities' => [],
            'aspirations' => []
          }
        )
      end
      
      before do
        previous_snapshot
      end
      
      it 'formats assignment changes correctly' do
        changes = helper.format_snapshot_changes(snapshot, person, organization, current_user: current_teammate, previous_snapshot: previous_snapshot)
        
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
      let(:previous_snapshot) do
        create(:maap_snapshot,
          employee: person,
          created_by: manager,
          company: organization,
          change_type: 'milestone_management',
          created_at: 2.days.ago,
          maap_data: {
            'employment_tenure' => nil,
            'assignments' => [],
            'abilities' => [
              {
                'ability_id' => ability.id,
                'milestone_level' => 1,
                'certified_by_id' => nil,
                'attained_at' => 1.year.ago.to_s
              }
            ],
            'aspirations' => []
          }
        )
      end
      let(:snapshot) do
        create(:maap_snapshot,
          employee: person,
          created_by: manager,
          company: organization,
          change_type: 'milestone_management',
          created_at: 1.day.ago,
          maap_data: {
            'position' => nil,
            'assignments' => [],
            'abilities' => [
              {
                'ability_id' => ability.id,
                'milestone_level' => 2,
                'certified_by_id' => manager.id,
                'attained_at' => 6.months.ago.to_s
              }
            ],
            'aspirations' => []
          }
        )
      end
      
      before do
        previous_snapshot
      end
      
      it 'formats milestone changes correctly' do
        changes = helper.format_snapshot_changes(snapshot, person, organization, current_user: current_teammate, previous_snapshot: previous_snapshot)
        
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
      let(:previous_snapshot) do
        create(:maap_snapshot,
          employee: person,
          created_by: manager,
          company: organization,
          change_type: 'exploration',
          created_at: 2.days.ago,
          maap_data: {
            'position' => nil,
            'assignments' => [],
            'abilities' => [],
            'aspirations' => []
          }
        )
      end
      let(:snapshot) do
        create(:maap_snapshot,
          employee: person,
          created_by: manager,
          company: organization,
          change_type: 'exploration',
          created_at: 1.day.ago,
          maap_data: {
            'position' => nil,
            'assignments' => [],
            'abilities' => [],
            'aspirations' => []
          }
        )
      end
      
      before do
        previous_snapshot
      end
      
      it 'returns empty hash when there are no changes' do
        changes = helper.format_snapshot_changes(snapshot, person, organization, current_user: current_teammate, previous_snapshot: previous_snapshot)
        
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
        changes = helper.format_snapshot_changes(snapshot, person, organization, current_user: current_teammate, previous_snapshot: nil)
        expect(changes).to be_a(Hash)
        expect(changes[:employment]).to be_nil
        expect(changes[:assignments]).to be_nil
        expect(changes[:milestones]).to be_nil
      end
    end

    context 'auto-finding previous snapshot' do
      let(:assignment) { create(:assignment, company: organization) }
      let(:previous_snapshot) do
        create(:maap_snapshot,
          employee: person,
          created_by: manager,
          company: organization,
          change_type: 'assignment_management',
          created_at: 2.days.ago,
          maap_data: {
            'assignments' => [
              {
                'assignment_id' => assignment.id,
                'anticipated_energy_percentage' => 20,
                'rated_assignment' => {}
              }
            ],
            'position' => nil,
            'abilities' => [],
            'aspirations' => []
          }
        )
      end
      let(:snapshot) do
        create(:maap_snapshot,
          employee: person,
          created_by: manager,
          company: organization,
          change_type: 'assignment_management',
          created_at: 1.day.ago,
          maap_data: {
            'assignments' => [
              {
                'assignment_id' => assignment.id,
                'anticipated_energy_percentage' => 50,
                'rated_assignment' => {}
              }
            ],
            'position' => nil,
            'abilities' => [],
            'aspirations' => []
          }
        )
      end

      before do
        previous_snapshot
      end

      it 'automatically finds previous snapshot when not provided' do
        # Don't pass previous_snapshot - should auto-find it
        changes = helper.format_snapshot_changes(snapshot, person, organization, current_user: current_teammate)
        
        expect(changes).to be_present
        expect(changes[:assignments]).to be_present
        expect(changes[:assignments].length).to eq(1)
        
        assignment_change = changes[:assignments].first
        energy_change = assignment_change[:changes].find { |c| c[:label] == 'Anticipated Energy' }
        expect(energy_change).to be_present
        expect(energy_change[:current]).to eq('20%')
        expect(energy_change[:proposed]).to eq('50%')
      end

      it 'uses explicitly provided previous_snapshot when given' do
        # Create a different snapshot that would be found if we didn't pass one
        other_snapshot = create(:maap_snapshot,
          employee: person,
          created_by: manager,
          company: organization,
          change_type: 'assignment_management',
          created_at: 1.5.days.ago,  # Between previous_snapshot and snapshot
          maap_data: {
            'assignments' => [
              {
                'assignment_id' => assignment.id,
                'anticipated_energy_percentage' => 30,
                'rated_assignment' => {}
              }
            ],
            'position' => nil,
            'abilities' => [],
            'aspirations' => []
          }
        )
        
        # Explicitly pass previous_snapshot - should use it, not other_snapshot
        changes = helper.format_snapshot_changes(snapshot, person, organization, current_user: current_teammate, previous_snapshot: previous_snapshot)
        
        assignment_change = changes[:assignments].first
        energy_change = assignment_change[:changes].find { |c| c[:label] == 'Anticipated Energy' }
        # Should compare against previous_snapshot (20%), not other_snapshot (30%)
        expect(energy_change[:current]).to eq('20%')
        expect(energy_change[:proposed]).to eq('50%')
      end

      it 'shows new changes for first snapshot when no previous exists' do
        # Ensure assignment exists (force lazy loading)
        assignment_record = assignment
        expect(assignment_record).to be_persisted
        expect(Assignment.exists?(assignment_record.id)).to be true
        
        # Delete previous_snapshot first so first_snapshot has no previous
        previous_snapshot.destroy
        
        # Verify assignment still exists after destroying previous_snapshot
        expect(Assignment.exists?(assignment_record.id)).to be true
        
        # Create a snapshot with no previous snapshots
        first_snapshot = create(:maap_snapshot,
          employee: person,
          created_by: manager,
          company: organization,
          change_type: 'assignment_management',
          created_at: 5.days.ago,  # Before previous_snapshot
          maap_data: {
            'assignments' => [
              {
                'assignment_id' => assignment_record.id,
                'anticipated_energy_percentage' => 10,
                'rated_assignment' => {}
              }
            ],
            'position' => nil,
            'abilities' => [],
            'aspirations' => []
          }
        )
        
        # Verify the assignment ID is in the snapshot's maap_data
        expect(first_snapshot.maap_data['assignments'].first['assignment_id']).to eq(assignment_record.id)
        
        changes = helper.format_snapshot_changes(first_snapshot, person, organization, current_user: current_teammate)
        
        # First snapshot should show all changes as "new"
        expect(changes).to be_present
        expect(changes[:assignments]).to be_present
        expect(changes[:assignments]).not_to be_empty
        assignment_change = changes[:assignments].first
        # Should have a change showing new assignment
        expect(assignment_change[:changes].length).to be > 0
        # Check for new_assignment in the formatted changes (uses label, not field)
        new_assignment_change = assignment_change[:changes].find { |c| c[:label] == 'New Assignment' }
        expect(new_assignment_change).to be_present
        expect(new_assignment_change[:current]).to eq('None')
        expect(new_assignment_change[:proposed]).to eq('10% energy')
      end
    end
    
    context 'with aspiration changes' do
      let(:aspiration) { create(:aspiration, organization: organization, name: 'Be Kind') }
      let(:previous_snapshot) do
        create(:maap_snapshot,
          employee: person,
          created_by: manager,
          company: organization,
          change_type: 'aspiration_management',
          created_at: 2.days.ago,
          maap_data: {
            'position' => nil,
            'assignments' => [],
            'abilities' => [],
            'aspirations' => [
              {
                'aspiration_id' => aspiration.id,
                'rated_assignment' => {}
              }
            ]
          }
        )
      end
      let(:snapshot) do
        create(:maap_snapshot,
          employee: person,
          created_by: manager,
          company: organization,
          change_type: 'aspiration_management',
          created_at: 1.day.ago,
          maap_data: {
            'position' => nil,
            'assignments' => [],
            'abilities' => [],
            'aspirations' => [
              {
                'aspiration_id' => aspiration.id,
                'official_rating' => 'meeting'
              }
            ]
          }
        )
      end
      
      before do
        previous_snapshot
      end
      
      it 'formats aspiration changes correctly' do
        changes = helper.format_snapshot_changes(snapshot, person, organization, current_user: current_teammate, previous_snapshot: previous_snapshot)
        
        expect(changes).to be_present
        expect(changes[:aspirations]).to be_present
        expect(changes[:aspirations].length).to eq(1)
        
        aspiration_change = changes[:aspirations].first
        expect(aspiration_change[:aspiration_name]).to eq(aspiration.name)
        expect(aspiration_change[:changes].length).to be > 0
        
        rating_change = aspiration_change[:changes].find { |c| c[:label] == 'Official Rating' }
        expect(rating_change).to be_present
        expect(rating_change[:current]).to eq('Not set')
        expect(rating_change[:proposed]).to eq('Meeting')
      end
    end
    
    context 'with position changes when current is "none"' do
      let(:position_major_level) { create(:position_major_level) }
      let(:position_type1) { create(:position_type, organization: organization, position_major_level: position_major_level, external_title: 'Engineer 1') }
      let(:position_level1) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
      let(:position1) { create(:position, position_type: position_type1, position_level: position_level1) }
      let(:snapshot) do
        create(:maap_snapshot,
          employee: person,
          created_by: manager,
          company: organization,
          change_type: 'position_tenure',
          created_at: 1.day.ago,
          maap_data: {
            'position' => {
              'position_id' => position1.id,
              'manager_id' => manager.id,
              'seat_id' => nil,
              'employment_type' => 'full_time',
              'rated_position' => {}
            },
            'assignments' => [],
            'abilities' => [],
            'aspirations' => []
          }
        )
      end
      
      it 'handles position changes when current is "none"' do
        # Update snapshot to have rated_position data to test "new rating" case
        snapshot.update!(maap_data: snapshot.maap_data.deep_merge({
          'position' => {
            'rated_position' => {
              'position_id' => position1.id,
              'manager_id' => manager.id,
              'seat_id' => nil,
              'employment_type' => 'full_time',
              'official_position_rating' => 2,
              'started_at' => 10.days.ago.iso8601,
              'ended_at' => 1.day.ago.iso8601
            }
          }
        }))
        
        changes = helper.format_snapshot_changes(snapshot, person, organization, current_user: current_teammate, previous_snapshot: nil)
        
        # When there's no previous snapshot and current has rated_position data, should show as new rating
        expect(changes).to be_present
        expect(changes[:employment]).to be_present
        new_rating_change = changes[:employment].find { |c| c[:label] == 'Rated Position' }
        expect(new_rating_change).to be_present
        expect(new_rating_change[:current]).to eq('None')
        expect(new_rating_change[:proposed]).to eq('New rating')
      end
    end
    
    context 'with employment_type and official_position_rating changes' do
      let(:position_major_level) { create(:position_major_level) }
      let(:position_type1) { create(:position_type, organization: organization, position_major_level: position_major_level, external_title: 'Engineer 1') }
      let(:position_level1) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
      let(:position1) { create(:position, position_type: position_type1, position_level: position_level1) }
      let(:previous_snapshot) do
        create(:maap_snapshot,
          employee: person,
          created_by: manager,
          company: organization,
          change_type: 'position_tenure',
          created_at: 2.days.ago,
          maap_data: {
            'position' => {
              'position_id' => position1.id,
              'manager_id' => manager.id,
              'seat_id' => nil,
              'employment_type' => 'full_time',
              'rated_position' => {
                'position_id' => position1.id,
                'manager_id' => manager.id,
                'seat_id' => nil,
                'employment_type' => 'part_time',
                'official_position_rating' => 2,
                'started_at' => 30.days.ago.iso8601,
                'ended_at' => 2.days.ago.iso8601
              }
            },
            'assignments' => [],
            'abilities' => [],
            'aspirations' => []
          }
        )
      end
      let(:snapshot) do
        create(:maap_snapshot,
          employee: person,
          created_by: manager,
          company: organization,
          change_type: 'position_tenure',
          created_at: 1.day.ago,
          maap_data: {
            'position' => {
              'position_id' => position1.id,
              'manager_id' => manager.id,
              'seat_id' => nil,
              'employment_type' => 'full_time',
              'rated_position' => {
                'position_id' => position1.id,
                'manager_id' => manager.id,
                'seat_id' => nil,
                'employment_type' => 'full_time',
                'official_position_rating' => 3,
                'started_at' => 2.days.ago.iso8601,
                'ended_at' => 1.day.ago.iso8601
              }
            },
            'assignments' => [],
            'abilities' => [],
            'aspirations' => []
          }
        )
      end
      
      before do
        previous_snapshot
      end
      
      it 'formats employment_type changes correctly' do
        changes = helper.format_snapshot_changes(snapshot, person, organization, current_user: current_teammate, previous_snapshot: previous_snapshot)
        
        expect(changes).to be_present
        expect(changes[:employment]).to be_present
        
        employment_type_change = changes[:employment].find { |c| c[:label] == 'Rated Employment Type' }
        expect(employment_type_change).to be_present
        expect(employment_type_change[:current]).to eq('Part time')
        expect(employment_type_change[:proposed]).to eq('Full time')
      end
      
      it 'formats official_position_rating changes correctly' do
        changes = helper.format_snapshot_changes(snapshot, person, organization, current_user: current_teammate, previous_snapshot: previous_snapshot)
        
        expect(changes).to be_present
        expect(changes[:employment]).to be_present
        
        rating_change = changes[:employment].find { |c| c[:label] == 'Official Position Rating' }
        expect(rating_change).to be_present
        expect(rating_change[:current]).to eq('2')
        expect(rating_change[:proposed]).to eq('3')
      end
    end
    
    context 'with assignment rating changes' do
      let(:assignment) { create(:assignment, company: organization) }
      let(:previous_snapshot) do
        create(:maap_snapshot,
          employee: person,
          created_by: manager,
          company: organization,
          change_type: 'assignment_management',
          created_at: 2.days.ago,
          maap_data: {
            'position' => nil,
            'assignments' => [
              {
                'assignment_id' => assignment.id,
                'anticipated_energy_percentage' => 50,
                'rated_assignment' => {
                  'assignment_id' => assignment.id,
                  'anticipated_energy_percentage' => 50,
                  'official_rating' => 'meeting',
                  'started_at' => 20.days.ago.to_time.iso8601,
                  'ended_at' => 2.days.ago.to_time.iso8601
                }
              }
            ],
            'abilities' => [],
            'aspirations' => []
          }
        )
      end
      let(:snapshot) do
        create(:maap_snapshot,
          employee: person,
          created_by: manager,
          company: organization,
          change_type: 'assignment_management',
          created_at: 1.day.ago,
          maap_data: {
            'position' => nil,
            'assignments' => [
              {
                'assignment_id' => assignment.id,
                'anticipated_energy_percentage' => 50,
                'rated_assignment' => {
                  'assignment_id' => assignment.id,
                  'anticipated_energy_percentage' => 50,
                  'official_rating' => 'exceeding',
                  'started_at' => 10.days.ago.to_time.iso8601,
                  'ended_at' => 1.day.ago.to_time.iso8601
                }
              }
            ],
            'abilities' => [],
            'aspirations' => []
          }
        )
      end
      
      before do
        previous_snapshot
      end
      
      it 'formats assignment rating changes correctly' do
        changes = helper.format_snapshot_changes(snapshot, person, organization, current_user: current_teammate, previous_snapshot: previous_snapshot)
        
        expect(changes).to be_present
        expect(changes[:assignments]).to be_present
        expect(changes[:assignments].length).to eq(1)
        
        assignment_change = changes[:assignments].first
        expect(assignment_change[:assignment_name]).to eq(assignment.title)
        
        rating_change = assignment_change[:changes].find { |c| c[:label] == 'Official Rating' }
        expect(rating_change).to be_present
        expect(rating_change[:current]).to eq('Meeting')
        expect(rating_change[:proposed]).to eq('Exceeding')
      end
    end
  end

  describe '#format_snapshot_all_fields' do
    let(:position_major_level) { create(:position_major_level) }
    let(:position_type) { create(:position_type, organization: organization, position_major_level: position_major_level, external_title: 'Engineer') }
    let(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
    let(:position) { create(:position, position_type: position_type, position_level: position_level) }
    let(:assignment) { create(:assignment, company: organization) }
    
    let(:previous_snapshot) do
      create(:maap_snapshot,
        employee: person,
        created_by: manager,
        company: organization,
        change_type: 'position_tenure',
        created_at: 2.days.ago,
        maap_data: {
          'position' => {
            'position_id' => position.id,
            'manager_id' => manager.id,
            'seat_id' => nil,
            'employment_type' => 'full_time',
            'rated_position' => {
              'position_id' => position.id,
              'manager_id' => manager.id,
              'seat_id' => nil,
              'employment_type' => 'part_time',
              'official_position_rating' => 2,
              'started_at' => 30.days.ago.iso8601,
              'ended_at' => 2.days.ago.iso8601
            }
          },
          'assignments' => [
            {
              'assignment_id' => assignment.id,
              'anticipated_energy_percentage' => 20,
              'rated_assignment' => {
                'anticipated_energy_percentage' => 20,
                'official_rating' => 'meeting',
                'started_at' => 20.days.ago.iso8601,
                'ended_at' => 2.days.ago.iso8601
              }
            }
          ],
          'abilities' => [],
          'aspirations' => []
        }
      )
    end
    
    let(:snapshot) do
      create(:maap_snapshot,
        employee: person,
        created_by: manager,
        company: organization,
        change_type: 'position_tenure',
        created_at: 1.day.ago,
        maap_data: {
          'position' => {
            'position_id' => position.id,
            'manager_id' => manager.id,
            'seat_id' => nil,
            'employment_type' => 'full_time',
            'rated_position' => {
              'position_id' => position.id,
              'manager_id' => manager.id,
              'seat_id' => nil,
              'employment_type' => 'full_time',
              'official_position_rating' => 3,
              'started_at' => 2.days.ago.iso8601,
              'ended_at' => 1.day.ago.iso8601
            }
          },
          'assignments' => [
            {
              'assignment_id' => assignment.id,
              'anticipated_energy_percentage' => 50,
              'rated_assignment' => {
                'anticipated_energy_percentage' => 50,
                'official_rating' => 'exceeding',
                'started_at' => 10.days.ago.iso8601,
                'ended_at' => 1.day.ago.iso8601
              }
            }
          ],
          'abilities' => [],
          'aspirations' => []
        }
      )
    end

    before do
      previous_snapshot
    end

    context 'with nil snapshot' do
      it 'returns nil for nil snapshot' do
        result = helper.format_snapshot_all_fields(nil, person, organization)
        expect(result).to be_nil
      end
    end

    context 'with valid snapshot' do
      it 'returns hash with correct keys' do
        result = helper.format_snapshot_all_fields(snapshot, person, organization, previous_snapshot: previous_snapshot)
        
        expect(result).to be_a(Hash)
        expect(result.keys).to match_array([:employment, :assignments, :abilities, :aspirations])
      end

      it 'filters out fields starting with "Rated" from employment fields' do
        result = helper.format_snapshot_all_fields(snapshot, person, organization, previous_snapshot: previous_snapshot)
        
        employment_fields = result[:employment]
        expect(employment_fields).to be_present
        
        field_labels = employment_fields.map { |f| f[:label] }
        
        # Should include non-rated fields
        expect(field_labels).to include('Position')
        expect(field_labels).to include('Manager')
        expect(field_labels).to include('Seat')
        expect(field_labels).to include('Employment Type')
        expect(field_labels).to include('Official Position Rating')
        
        # Should exclude rated fields
        expect(field_labels).not_to include('Rated Position')
        expect(field_labels).not_to include('Rated Manager')
        expect(field_labels).not_to include('Rated Seat')
        expect(field_labels).not_to include('Rated Employment Type')
        expect(field_labels).not_to include('Rated Start Date')
        expect(field_labels).not_to include('Rated End Date')
      end

      it 'filters out fields starting with "Rated" from assignment fields' do
        result = helper.format_snapshot_all_fields(snapshot, person, organization, previous_snapshot: previous_snapshot)
        
        assignment_data = result[:assignments]
        expect(assignment_data).to be_present
        expect(assignment_data.length).to eq(1)
        
        assignment_fields = assignment_data.first[:fields]
        field_labels = assignment_fields.map { |f| f[:label] }
        
        # Should include non-rated fields
        expect(field_labels).to include('Anticipated Energy')
        expect(field_labels).to include('Official Rating')
        
        # Should exclude rated fields
        expect(field_labels).not_to include('Rated Anticipated Energy')
        expect(field_labels).not_to include('Rated Start Date')
        expect(field_labels).not_to include('Rated End Date')
      end

      it 'includes non-rated fields correctly' do
        result = helper.format_snapshot_all_fields(snapshot, person, organization, previous_snapshot: previous_snapshot)
        
        # Check employment fields have correct values
        employment_fields = result[:employment]
        position_field = employment_fields.find { |f| f[:label] == 'Position' }
        expect(position_field).to be_present
        expect(position_field[:old]).to be_present
        expect(position_field[:new]).to be_present
        
        # Check assignment fields have correct values
        assignment_data = result[:assignments]
        assignment_fields = assignment_data.first[:fields]
        energy_field = assignment_fields.find { |f| f[:label] == 'Anticipated Energy' }
        expect(energy_field).to be_present
        expect(energy_field[:old]).to eq('20%')
        expect(energy_field[:new]).to eq('50%')
      end

      it 'handles empty data gracefully' do
        empty_snapshot = create(:maap_snapshot,
          employee: person,
          created_by: manager,
          company: organization,
          change_type: 'exploration',
          created_at: 1.day.ago,
          maap_data: {
            'position' => nil,
            'assignments' => [],
            'abilities' => [],
            'aspirations' => []
          }
        )
        
        result = helper.format_snapshot_all_fields(empty_snapshot, person, organization, previous_snapshot: nil)
        
        expect(result).to be_a(Hash)
        expect(result[:employment]).to be_present
        expect(result[:assignments]).to be_an(Array)
        expect(result[:abilities]).to be_an(Array)
        expect(result[:aspirations]).to be_an(Array)
      end

      it 'handles nil/empty rated_position data' do
        snapshot_no_rated = create(:maap_snapshot,
          employee: person,
          created_by: manager,
          company: organization,
          change_type: 'position_tenure',
          created_at: 1.day.ago,
          maap_data: {
            'position' => {
              'position_id' => position.id,
              'manager_id' => manager.id,
              'seat_id' => nil,
              'employment_type' => 'full_time',
              'rated_position' => {}
            },
            'assignments' => [],
            'abilities' => [],
            'aspirations' => []
          }
        )
        
        result = helper.format_snapshot_all_fields(snapshot_no_rated, person, organization, previous_snapshot: nil)
        
        employment_fields = result[:employment]
        field_labels = employment_fields.map { |f| f[:label] }
        
        # Should still filter out rated fields even when empty
        expect(field_labels).not_to include('Rated Position')
        expect(field_labels).not_to include('Rated Manager')
        expect(field_labels).not_to include('Rated Start Date')
      end

      it 'handles nil/empty rated_assignment data' do
        snapshot_no_rated_assignment = create(:maap_snapshot,
          employee: person,
          created_by: manager,
          company: organization,
          change_type: 'assignment_management',
          created_at: 1.day.ago,
          maap_data: {
            'position' => nil,
            'assignments' => [
              {
                'assignment_id' => assignment.id,
                'anticipated_energy_percentage' => 50,
                'rated_assignment' => {}
              }
            ],
            'abilities' => [],
            'aspirations' => []
          }
        )
        
        result = helper.format_snapshot_all_fields(snapshot_no_rated_assignment, person, organization, previous_snapshot: nil)
        
        assignment_data = result[:assignments]
        assignment_fields = assignment_data.first[:fields]
        field_labels = assignment_fields.map { |f| f[:label] }
        
        # Should still filter out rated fields even when empty
        expect(field_labels).not_to include('Rated Anticipated Energy')
        expect(field_labels).not_to include('Rated Start Date')
        expect(field_labels).not_to include('Rated End Date')
      end

      it 'works correctly with multiple assignments' do
        assignment2 = create(:assignment, company: organization)
        
        snapshot_multiple = create(:maap_snapshot,
          employee: person,
          created_by: manager,
          company: organization,
          change_type: 'assignment_management',
          created_at: 1.day.ago,
          maap_data: {
            'position' => nil,
            'assignments' => [
              {
                'assignment_id' => assignment.id,
                'anticipated_energy_percentage' => 50,
                'rated_assignment' => {
                  'anticipated_energy_percentage' => 50,
                  'official_rating' => 'exceeding',
                  'started_at' => 10.days.ago.iso8601,
                  'ended_at' => 1.day.ago.iso8601
                }
              },
              {
                'assignment_id' => assignment2.id,
                'anticipated_energy_percentage' => 30,
                'rated_assignment' => {
                  'anticipated_energy_percentage' => 30,
                  'official_rating' => 'meeting',
                  'started_at' => 5.days.ago.iso8601,
                  'ended_at' => 1.day.ago.iso8601
                }
              }
            ],
            'abilities' => [],
            'aspirations' => []
          }
        )
        
        result = helper.format_snapshot_all_fields(snapshot_multiple, person, organization, previous_snapshot: nil)
        
        expect(result[:assignments].length).to eq(2)
        
        result[:assignments].each do |assignment_data|
          field_labels = assignment_data[:fields].map { |f| f[:label] }
          
          # Should exclude rated fields for all assignments
          expect(field_labels).not_to include('Rated Anticipated Energy')
          expect(field_labels).not_to include('Rated Start Date')
          expect(field_labels).not_to include('Rated End Date')
          
          # Should include non-rated fields
          expect(field_labels).to include('Anticipated Energy')
          expect(field_labels).to include('Official Rating')
        end
      end
    end
  end
end

