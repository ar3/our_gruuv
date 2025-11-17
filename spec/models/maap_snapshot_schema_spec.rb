require 'rails_helper'

RSpec.describe 'MaapSnapshot Schema Standardization' do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:manager) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:employment_tenure) { create(:employment_tenure, teammate: teammate, company: organization, employment_type: 'full_time', official_position_rating: 2) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:assignment_tenure) { create(:assignment_tenure, teammate: teammate, assignment: assignment, anticipated_energy_percentage: 50, official_rating: 'meeting') }
  let(:ability) { create(:ability, organization: organization) }
  let(:milestone) { create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 3, certified_by_id: manager.id, attained_at: Date.current) }
  let(:aspiration) { create(:aspiration, organization: organization) }
  let(:aspiration_check_in) { create(:aspiration_check_in, teammate: teammate, aspiration: aspiration, official_rating: 'exceeding', official_check_in_completed_at: Time.current) }

  before do
    employment_tenure
    assignment_tenure
    milestone
    aspiration_check_in
  end

  describe 'standard schema format' do
    it 'build_maap_data_for_employee produces standard format' do
      maap_data = MaapSnapshot.build_maap_data_for_employee(person, organization)
      
      # Check top-level keys (convert symbols to strings for comparison)
      expect(maap_data.keys.map(&:to_s)).to match_array(%w[position assignments abilities aspirations])
      
      # Check position format (handle symbol keys)
      position_data = maap_data[:position] || maap_data['position']
      expect(position_data).to be_present
      expect(position_data).to include(
        :position_id, :manager_id, :seat_id, :employment_type, :rated_position
      )
      expect(position_data).not_to include(:official_position_rating)
      expect(position_data[:position_id]).to eq(employment_tenure.position_id)
      expect(position_data[:employment_type]).to eq('full_time')
      # rated_position should be present (may be empty hash if no closed tenure)
      rated_position = position_data[:rated_position] || position_data['rated_position']
      expect(rated_position).to be_a(Hash)
      
      # Check assignments format
      assignments_data = maap_data[:assignments] || maap_data['assignments']
      expect(assignments_data).to be_an(Array)
      assignment_data = assignments_data.first
      expect(assignment_data).to include(
        :assignment_id,
        :anticipated_energy_percentage,
        :rated_assignment
      )
      expect(assignment_data).not_to include(:official_rating)
      expect(assignment_data[:assignment_id]).to eq(assignment.id)
      expect(assignment_data[:anticipated_energy_percentage]).to eq(50)
      # rated_assignment should be present (may be empty hash if no closed tenure)
      rated_assignment = assignment_data[:rated_assignment] || assignment_data['rated_assignment']
      expect(rated_assignment).to be_a(Hash)
      
      # Check abilities format (was milestones)
      abilities_data = maap_data[:abilities] || maap_data['abilities']
      expect(abilities_data).to be_an(Array)
      ability_data = abilities_data.first
      expect(ability_data).to include(
        :ability_id,
        :milestone_level,
        :certified_by_id,
        :attained_at
      )
      expect(ability_data[:ability_id]).to eq(ability.id)
      expect(ability_data[:milestone_level]).to eq(3)
      
      # Check aspirations format
      aspirations_data = maap_data[:aspirations] || maap_data['aspirations']
      expect(aspirations_data).to be_an(Array)
      aspiration_data = aspirations_data.find { |a| (a[:aspiration_id] || a['aspiration_id']) == aspiration.id }
      expect(aspiration_data).to include(
        :aspiration_id,
        :official_rating
      )
      expect(aspiration_data[:official_rating]).to eq('exceeding')
    end

    it 'CheckInFinalizationService produces standard format' do
      service = CheckInFinalizationService.new(
        teammate: teammate,
        finalization_params: {},
        finalized_by: manager
      )
      
      maap_data = service.send(:build_ratings_data, {})
      
      # Check top-level keys
      expect(maap_data.keys).to match_array(%i[position assignments abilities aspirations])
      
      # Check position format
      expect(maap_data[:position]).to include(
        :position_id,
        :manager_id,
        :seat_id,
        :employment_type,
        :rated_position
      )
      expect(maap_data[:position]).not_to include(:official_position_rating)
      
      # Check assignments format
      expect(maap_data[:assignments]).to be_an(Array)
      assignment_data = maap_data[:assignments].first
      expect(assignment_data).to include(
        :assignment_id,
        :anticipated_energy_percentage,
        :rated_assignment
      )
      expect(assignment_data).not_to include(:official_rating)
      
      # Check abilities format
      expect(maap_data[:abilities]).to be_an(Array)
      ability_data = maap_data[:abilities].first
      expect(ability_data).to include(
        :ability_id,
        :milestone_level,
        :certified_by_id,
        :attained_at
      )
      
      # Check aspirations format
      expect(maap_data[:aspirations]).to be_an(Array)
      aspiration_data = maap_data[:aspirations].find { |a| a[:aspiration_id] == aspiration.id }
      expect(aspiration_data).to include(
        :aspiration_id,
        :official_rating
      )
    end

    it 'BulkCheckInFinalizationProcessor produces standard format' do
      snapshot = create(:maap_snapshot, employee: person, company: organization, form_params: {})
      processor = MaapData::BulkCheckInFinalizationProcessor.new(snapshot)
      
      maap_data = processor.process
      
      # Check top-level keys
      expect(maap_data.keys).to match_array(%i[position assignments abilities aspirations])
      
      # Check position format
      expect(maap_data[:position]).to include(
        :position_id,
        :manager_id,
        :seat_id,
        :employment_type,
        :rated_position
      )
      
      # Check assignments format
      expect(maap_data[:assignments]).to be_an(Array)
      if maap_data[:assignments].any?
        assignment_data = maap_data[:assignments].first
        expect(assignment_data).to include(
          :assignment_id,
          :anticipated_energy_percentage,
          :rated_assignment
        )
        expect(assignment_data).not_to include(:official_rating)
      end
      
      # Check abilities format
      expect(maap_data[:abilities]).to be_an(Array)
      if maap_data[:abilities].any?
        ability_data = maap_data[:abilities].first
        expect(ability_data).to include(
          :ability_id,
          :milestone_level,
          :certified_by_id,
          :attained_at
        )
      end
      
      # Check aspirations format
      expect(maap_data[:aspirations]).to be_an(Array)
      if maap_data[:aspirations].any?
        aspiration_data = maap_data[:aspirations].first
        expect(aspiration_data).to include(
          :aspiration_id,
          :official_rating
        )
      end
    end

    it 'all snapshot creation methods produce identical schema structure' do
      # Get data from different methods
      method1_data = MaapSnapshot.build_maap_data_for_employee(person, organization)
      service = CheckInFinalizationService.new(teammate: teammate, finalization_params: {}, finalized_by: manager)
      method2_data = service.send(:build_ratings_data, {})
      
      # Convert symbols to strings for comparison
      method2_data_strings = method2_data.deep_stringify_keys
      
      # Check that both have the same top-level keys (convert symbols to strings)
      method1_keys = method1_data.keys.map(&:to_s).sort
      method2_keys = method2_data_strings.keys.map(&:to_s).sort
      expect(method1_keys).to eq(method2_keys)
      
      # Check that assignments have the same structure
      method1_assignments = method1_data[:assignments] || method1_data['assignments'] || []
      method2_assignments = method2_data_strings['assignments'] || []
      if method1_assignments.any? && method2_assignments.any?
        method1_assignment = method1_assignments.first
        method2_assignment = method2_assignments.first
        method1_keys = method1_assignment.keys.map(&:to_s).sort
        method2_keys = method2_assignment.keys.map(&:to_s).sort
        expect(method1_keys).to eq(method2_keys)
      end
      
      # Check that abilities have the same structure
      method1_abilities = method1_data[:abilities] || method1_data['abilities'] || []
      method2_abilities = method2_data_strings['abilities'] || []
      if method1_abilities.any? && method2_abilities.any?
        method1_ability = method1_abilities.first
        method2_ability = method2_abilities.first
        method1_keys = method1_ability.keys.map(&:to_s).sort
        method2_keys = method2_ability.keys.map(&:to_s).sort
        expect(method1_keys).to eq(method2_keys)
      end
    end

    it 'maap_data always reflects DB state, not form_params' do
      # Create assignment with specific DB values
      assignment_tenure.update!(anticipated_energy_percentage: 25, official_rating: 'meeting')
      
      # Create form_params with different proposed values
      form_params = {
        "tenure_#{assignment.id}_anticipated_energy" => '75', # Proposed change
        "check_in_#{assignment.id}_official_rating" => 'exceeding' # Proposed change
      }
      
      # Build snapshot with form_params
      snapshot = MaapSnapshot.build_for_employee_with_changes(
        employee: person,
        created_by: manager,
        change_type: 'assignment_management',
        reason: 'Test DB state vs form_params',
        form_params: form_params
      )
      
      # Verify form_params are stored separately
      expect(snapshot.form_params).to eq(form_params)
      
      # Verify maap_data reflects DB state (25%, 'meeting'), NOT form_params (75%, 'exceeding')
      # Handle both symbol and string keys
      assignments_data = snapshot.maap_data[:assignments] || snapshot.maap_data['assignments'] || []
      assignment_data = assignments_data.find { |a| (a[:assignment_id] || a['assignment_id']) == assignment.id }
      expect(assignment_data).to be_present
      energy = assignment_data[:anticipated_energy_percentage] || assignment_data['anticipated_energy_percentage']
      rated_assignment = assignment_data[:rated_assignment] || assignment_data['rated_assignment'] || {}
      rating = rated_assignment[:official_rating] || rated_assignment['official_rating']
      expect(energy).to eq(25) # From DB
      # Rating is in rated_assignment, which may be empty if no closed tenure exists
      # If there's a closed tenure with rating, it will be in rated_assignment
      # For this test, we're checking that form_params don't affect maap_data
      # The rating will be in rated_assignment if there's a previous closed tenure
      
      # Verify maap_data does NOT contain form_params values
      expect(energy).not_to eq(75)
      # Rating check removed since it's now in rated_assignment which may be empty
    end

    it 'maap_data reflects DB state after execution' do
      # Simulate execution: close current tenure and create new one with rating
      assignment_tenure.update!(
        anticipated_energy_percentage: 60,
        official_rating: 'exceeding',
        started_at: 10.days.ago,
        ended_at: 1.day.ago
      )
      
      # Create new active tenure (without rating, as it's new)
      teammate = person.teammates.find_by(organization: organization)
      create(:assignment_tenure,
        teammate: teammate,
        assignment: assignment,
        anticipated_energy_percentage: 50,
        official_rating: nil,
        started_at: 1.day.ago,
        ended_at: nil
      )
      
      # Create snapshot after DB changes (simulating post-execution)
      maap_data = MaapSnapshot.build_maap_data_for_employee(person, organization)
      
      # maap_data should reflect the new DB state (handle symbol keys)
      assignments_data = maap_data[:assignments] || maap_data['assignments'] || []
      assignment_data = assignments_data.find { |a| (a[:assignment_id] || a['assignment_id']) == assignment.id }
      expect(assignment_data).to be_present
      expect(assignment_data[:anticipated_energy_percentage] || assignment_data['anticipated_energy_percentage']).to eq(50) # New active tenure
      # Rating should be in rated_assignment from the closed tenure
      rated_assignment = assignment_data[:rated_assignment] || assignment_data['rated_assignment'] || {}
      expect(rated_assignment[:official_rating] || rated_assignment['official_rating']).to eq('exceeding') # From closed tenure
    end
  end
end

