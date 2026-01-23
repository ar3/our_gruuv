require 'rails_helper'

RSpec.describe 'MaapSnapshot Assignment Schema with Rated Assignment' do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:manager) { create(:person) }
  let(:teammate) { create(:company_teammate, person: person, organization: organization) }
  let(:assignment) { create(:assignment, company: organization) }
  
  describe 'assignment schema structure' do
    context 'when there is a previous closed assignment tenure' do
      let!(:closed_tenure) do
        create(:assignment_tenure,
          teammate: teammate,
          assignment: assignment,
          anticipated_energy_percentage: 45,
          official_rating: 'meeting',
          started_at: 30.days.ago,
          ended_at: 10.days.ago
        )
      end
      let!(:active_tenure) do
        create(:assignment_tenure,
          teammate: teammate,
          assignment: assignment,
          anticipated_energy_percentage: 50,
          official_rating: nil,
          started_at: 10.days.ago,
          ended_at: nil
        )
      end
      
      it 'includes rated_assignment with data from closed tenure' do
        maap_data = MaapSnapshot.build_maap_data_for_teammate(teammate)
        assignments_data = maap_data[:assignments] || maap_data['assignments']
        
        expect(assignments_data).to be_an(Array)
        assignment_data = assignments_data.find { |a| (a[:assignment_id] || a['assignment_id']) == assignment.id }
        expect(assignment_data).to be_present
        
        expect(assignment_data).to include(
          :assignment_id, :anticipated_energy_percentage, :rated_assignment
        )
        expect(assignment_data).not_to include(:official_rating)
        
        # Top-level should come from active tenure
        expect(assignment_data[:assignment_id] || assignment_data['assignment_id']).to eq(active_tenure.assignment_id)
        expect(assignment_data[:anticipated_energy_percentage] || assignment_data['anticipated_energy_percentage']).to eq(active_tenure.anticipated_energy_percentage)
        
        # rated_assignment should come from closed tenure
        rated_assignment = assignment_data[:rated_assignment] || assignment_data['rated_assignment']
        expect(rated_assignment).to be_a(Hash)
        expect(rated_assignment).not_to be_empty
        expect(rated_assignment[:assignment_id] || rated_assignment['assignment_id']).to eq(closed_tenure.assignment_id)
        expect(rated_assignment[:anticipated_energy_percentage] || rated_assignment['anticipated_energy_percentage']).to eq(closed_tenure.anticipated_energy_percentage)
        expect(rated_assignment[:official_rating] || rated_assignment['official_rating']).to eq(closed_tenure.official_rating)
        expect(rated_assignment[:started_at] || rated_assignment['started_at']).to be_present
        expect(rated_assignment[:ended_at] || rated_assignment['ended_at']).to be_present
        # Verify timestamps (not dates)
        started_at = rated_assignment[:started_at] || rated_assignment['started_at']
        expect(started_at).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/) # ISO8601 timestamp format
      end
    end
    
    context 'when there is no previous closed assignment tenure' do
      let!(:active_tenure) do
        create(:assignment_tenure,
          teammate: teammate,
          assignment: assignment,
          anticipated_energy_percentage: 50,
          official_rating: nil,
          started_at: 10.days.ago,
          ended_at: nil
        )
      end
      
      it 'includes rated_assignment as empty hash' do
        maap_data = MaapSnapshot.build_maap_data_for_teammate(teammate)
        assignments_data = maap_data[:assignments] || maap_data['assignments']
        assignment_data = assignments_data.find { |a| (a[:assignment_id] || a['assignment_id']) == assignment.id }
        
        expect(assignment_data).to be_present
        expect(assignment_data).to include(:rated_assignment)
        
        rated_assignment = assignment_data[:rated_assignment] || assignment_data['rated_assignment']
        expect(rated_assignment).to be_a(Hash)
        expect(rated_assignment).to be_empty
      end
    end
    
    context 'when there are multiple closed tenures for the same assignment' do
      let!(:oldest_closed) do
        create(:assignment_tenure,
          teammate: teammate,
          assignment: assignment,
          anticipated_energy_percentage: 30,
          official_rating: 'not_meeting',
          started_at: 60.days.ago,
          ended_at: 30.days.ago
        )
      end
      let!(:most_recent_closed) do
        create(:assignment_tenure,
          teammate: teammate,
          assignment: assignment,
          anticipated_energy_percentage: 45,
          official_rating: 'meeting',
          started_at: 30.days.ago,
          ended_at: 10.days.ago
        )
      end
      let!(:active_tenure) do
        create(:assignment_tenure,
          teammate: teammate,
          assignment: assignment,
          anticipated_energy_percentage: 50,
          official_rating: nil,
          started_at: 10.days.ago,
          ended_at: nil
        )
      end
      
      it 'uses the most recent closed tenure (by ended_at DESC)' do
        maap_data = MaapSnapshot.build_maap_data_for_teammate(teammate)
        assignments_data = maap_data[:assignments] || maap_data['assignments']
        assignment_data = assignments_data.find { |a| (a[:assignment_id] || a['assignment_id']) == assignment.id }
        rated_assignment = assignment_data[:rated_assignment] || assignment_data['rated_assignment']
        
        expect(rated_assignment).not_to be_empty
        expect(rated_assignment[:official_rating] || rated_assignment['official_rating']).to eq(most_recent_closed.official_rating)
        expect(rated_assignment[:anticipated_energy_percentage] || rated_assignment['anticipated_energy_percentage']).to eq(most_recent_closed.anticipated_energy_percentage)
        expect(rated_assignment[:official_rating] || rated_assignment['official_rating']).not_to eq(oldest_closed.official_rating)
      end
    end
  end
end

