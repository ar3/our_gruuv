require 'rails_helper'

RSpec.describe MaapChangeDetectionService, 'previous snapshot comparison' do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:manager) { create(:person) }
  let(:person_teammate) { create(:teammate, person: person, organization: organization) }
  let(:assignment1) { create(:assignment, company: organization) }
  let(:assignment2) { create(:assignment, company: organization) }
  let(:ability) { create(:ability, organization: organization) }

  describe 'first snapshot (no previous)' do
    let(:snapshot) do
      create(:maap_snapshot,
        employee: person,
        created_by: manager,
        company: organization,
        change_type: 'assignment_management',
        maap_data: {
          'assignments' => [
            {
              'assignment_id' => assignment1.id,
              'anticipated_energy_percentage' => 50,
              'official_rating' => 'meeting'
            }
          ],
          'position' => {
            'position_id' => 1,
            'manager_id' => manager.id,
            'seat_id' => nil,
            'employment_type' => 'full_time',
            'official_position_rating' => nil
          },
          'abilities' => [
            {
              'ability_id' => ability.id,
              'milestone_level' => 2,
              'certified_by_id' => manager.id,
              'attained_at' => '2025-06-01'
            }
          ],
          'aspirations' => []
        }
      )
    end

    it 'treats first snapshot as all new changes' do
      service = described_class.new(
        person: person,
        maap_snapshot: snapshot,
        current_user: manager,
        previous_snapshot: nil
      )

      expect(service.change_counts[:assignments]).to eq(1)
      expect(service.change_counts[:employment]).to eq(1)
      expect(service.change_counts[:milestones]).to eq(1)
    end

    it 'shows employment as new in details' do
      service = described_class.new(
        person: person,
        maap_snapshot: snapshot,
        current_user: manager,
        previous_snapshot: nil
      )

      details = service.detailed_changes[:employment]
      expect(details[:has_changes]).to be true
      expect(details[:details].first[:field]).to eq('position')
      expect(details[:details].first[:current]).to eq('none')
      expect(details[:details].first[:proposed]).to eq('new position')
    end

    it 'shows assignment tenure as new in details' do
      service = described_class.new(
        person: person,
        maap_snapshot: snapshot,
        current_user: manager,
        previous_snapshot: nil
      )

      details = service.detailed_changes[:assignments]
      expect(details[:has_changes]).to be true
      assignment_changes = details[:details].first
      expect(assignment_changes[:changes].any? { |c| c[:field] == 'new_assignment' }).to be true
    end
  end

  describe 'multiple snapshots in sequence' do
    let(:snapshot1) do
      create(:maap_snapshot,
        employee: person,
        created_by: manager,
        company: organization,
        change_type: 'assignment_management',
        created_at: 3.days.ago,
        maap_data: {
          'assignments' => [
            {
              'assignment_id' => assignment1.id,
              'anticipated_energy_percentage' => 20,
              'official_rating' => nil
            }
          ],
          'position' => {
            'position_id' => 1,
            'manager_id' => manager.id,
            'seat_id' => nil,
            'employment_type' => 'full_time',
            'official_position_rating' => nil
          },
          'abilities' => [],
          'aspirations' => []
        }
      )
    end

    let(:snapshot2) do
      create(:maap_snapshot,
        employee: person,
        created_by: manager,
        company: organization,
        change_type: 'assignment_management',
        created_at: 2.days.ago,
        maap_data: {
          'assignments' => [
            {
              'assignment_id' => assignment1.id,
              'anticipated_energy_percentage' => 50,  # Changed from 20
              'official_rating' => nil
            }
          ],
          'position' => {
            'position_id' => 1,
            'manager_id' => manager.id,
            'seat_id' => nil,
            'employment_type' => 'full_time',
            'official_position_rating' => nil
          },
          'abilities' => [],
          'aspirations' => []
        }
      )
    end

    let(:snapshot3) do
      create(:maap_snapshot,
        employee: person,
        created_by: manager,
        company: organization,
        change_type: 'assignment_management',
        created_at: 1.day.ago,
        maap_data: {
          'assignments' => [
            {
              'assignment_id' => assignment1.id,
              'anticipated_energy_percentage' => 50,  # Same as snapshot2
              'official_rating' => nil
            }
          ],
          'position' => {
            'position_id' => 1,
            'manager_id' => manager.id,
            'seat_id' => nil,
            'employment_type' => 'full_time',
            'official_position_rating' => nil
          },
          'abilities' => [],
          'aspirations' => []
        }
      )
    end

    it 'compares snapshot2 against snapshot1' do
      service = described_class.new(
        person: person,
        maap_snapshot: snapshot2,
        current_user: manager,
        previous_snapshot: snapshot1
      )

      expect(service.change_counts[:assignments]).to eq(1)
      details = service.detailed_changes[:assignments]
      assignment_changes = details[:details].first
      energy_change = assignment_changes[:changes].find { |c| c[:field] == 'anticipated_energy_percentage' }
      expect(energy_change[:current]).to eq(20)
      expect(energy_change[:proposed]).to eq(50)
    end

    it 'compares snapshot3 against snapshot2' do
      service = described_class.new(
        person: person,
        maap_snapshot: snapshot3,
        current_user: manager,
        previous_snapshot: snapshot2
      )

      # snapshot3 has same values as snapshot2, so no changes
      expect(service.change_counts[:assignments]).to eq(0)
    end
  end

  describe 'snapshots with different assignment IDs' do
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
              'assignment_id' => assignment1.id,
              'anticipated_energy_percentage' => 30,
              'official_rating' => nil
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
              'assignment_id' => assignment1.id,
              'anticipated_energy_percentage' => 30,  # Same
              'official_rating' => nil
            },
            {
              'assignment_id' => assignment2.id,  # New assignment
              'anticipated_energy_percentage' => 50,
              'official_rating' => nil
            }
          ],
          'position' => nil,
          'abilities' => [],
          'aspirations' => []
        }
      )
    end

    it 'detects new assignment as change' do
      service = described_class.new(
        person: person,
        maap_snapshot: snapshot,
        current_user: manager,
        previous_snapshot: previous_snapshot
      )

      expect(service.change_counts[:assignments]).to eq(1)
      details = service.detailed_changes[:assignments]
      expect(details[:details].length).to eq(1)
      expect(details[:details].first[:assignment_id]).to eq(assignment2.id)
      expect(details[:details].first[:changes].any? { |c| c[:field] == 'new_assignment' }).to be true
    end

    it 'does not show unchanged assignment' do
      service = described_class.new(
        person: person,
        maap_snapshot: snapshot,
        current_user: manager,
        previous_snapshot: previous_snapshot
      )

      details = service.detailed_changes[:assignments]
      assignment_ids = details[:details].map { |d| d[:assignment_id] }
      expect(assignment_ids).not_to include(assignment1.id)
    end
  end

  describe 'snapshots with different milestone ability_ids' do
    let(:ability2) { create(:ability, organization: organization) }
    
    let(:previous_snapshot) do
      create(:maap_snapshot,
        employee: person,
        created_by: manager,
        company: organization,
        change_type: 'milestone_management',
        created_at: 2.days.ago,
        maap_data: {
          'assignments' => [],
          'position' => nil,
          'abilities' => [
            {
              'ability_id' => ability.id,
              'milestone_level' => 1,
              'certified_by_id' => nil,
              'attained_at' => '2025-01-01'
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
          'assignments' => [],
          'position' => nil,
          'abilities' => [
            {
              'ability_id' => ability.id,
              'milestone_level' => 2,  # Changed from 1
              'certified_by_id' => manager.id,
              'attained_at' => '2025-06-01'
            },
            {
              'ability_id' => ability2.id,  # New milestone
              'milestone_level' => 3,
              'certified_by_id' => manager.id,
              'attained_at' => '2025-06-15'
            }
          ],
          'aspirations' => []
        }
      )
    end

    it 'detects changes to existing milestone and new milestone' do
      service = described_class.new(
        person: person,
        maap_snapshot: snapshot,
        current_user: manager,
        previous_snapshot: previous_snapshot
      )

      expect(service.change_counts[:milestones]).to eq(2)
      details = service.detailed_changes[:milestones]
      expect(details[:details].length).to eq(2)
      
      ability1_changes = details[:details].find { |d| d[:ability_id] == ability.id }
      expect(ability1_changes).to be_present
      expect(ability1_changes[:changes].any? { |c| c[:field] == 'milestone_level' }).to be true
      
      ability2_changes = details[:details].find { |d| d[:ability_id] == ability2.id }
      expect(ability2_changes).to be_present
      expect(ability2_changes[:changes].any? { |c| c[:field] == 'milestone_level' }).to be true
    end
  end

  describe 'edge cases' do
    let(:snapshot) do
      create(:maap_snapshot,
        employee: person,
        created_by: manager,
        company: organization,
        change_type: 'assignment_management',
        maap_data: {
          'assignments' => [],
          'employment_tenure' => nil,
          'milestones' => []
        }
      )
    end

    it 'handles nil previous_snapshot gracefully' do
      service = described_class.new(
        person: person,
        maap_snapshot: snapshot,
        current_user: manager,
        previous_snapshot: nil
      )

      expect { service.change_counts }.not_to raise_error
      expect { service.detailed_changes }.not_to raise_error
    end

    it 'handles previous snapshot with missing keys' do
      previous_snapshot = create(:maap_snapshot, :exploration,
        created_by: manager,
        company: organization
      )

      service = described_class.new(
        person: person,
        maap_snapshot: snapshot,
        current_user: manager,
        previous_snapshot: previous_snapshot
      )

      expect { service.change_counts }.not_to raise_error
      expect { service.detailed_changes }.not_to raise_error
    end
  end

  describe 'assignment rating changes' do
    let(:assignment1) { create(:assignment, company: organization) }
    
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
              'assignment_id' => assignment1.id,
              'anticipated_energy_percentage' => 50,
              'official_rating' => 'meeting'
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
              'assignment_id' => assignment1.id,
              'anticipated_energy_percentage' => 50,  # Same
              'official_rating' => 'exceeding'  # Changed
            }
          ],
          'position' => nil,
          'abilities' => [],
          'aspirations' => []
        }
      )
    end

    it 'detects official_rating change' do
      service = described_class.new(
        person: person,
        maap_snapshot: snapshot,
        current_user: manager,
        previous_snapshot: previous_snapshot
      )

      expect(service.change_counts[:assignments]).to eq(1)
      details = service.detailed_changes[:assignments]
      assignment_changes = details[:details].first
      change_fields = assignment_changes[:changes].map { |c| c[:field] }
      
      expect(change_fields).to include('official_rating')
      rating_change = assignment_changes[:changes].find { |c| c[:field] == 'official_rating' }
      expect(rating_change[:current]).to eq('meeting')
      expect(rating_change[:proposed]).to eq('exceeding')
    end
  end
end

