require 'rails_helper'

RSpec.describe 'MaapSnapshot Position Schema with Rated Position' do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:manager) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:position_major_level) { create(:position_major_level) }
  let(:position_type) { create(:position_type, organization: organization, position_major_level: position_major_level, external_title: 'Engineer 1') }
  let(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let(:position) { create(:position, position_type: position_type, position_level: position_level) }
  # Seat is optional for employment tenures
  
  describe 'position schema structure' do
    context 'when there is a previous closed employment tenure' do
      let!(:closed_tenure) do
        create(:employment_tenure,
          teammate: teammate,
          company: organization,
          position: position,
          manager: manager,
          seat: nil,
          employment_type: 'full_time',
          official_position_rating: 2,
          started_at: 30.days.ago,
          ended_at: 10.days.ago
        )
      end
      let!(:active_tenure) do
        create(:employment_tenure,
          teammate: teammate,
          company: organization,
          position: position,
          manager: manager,
          seat: nil,
          employment_type: 'full_time',
          official_position_rating: nil,
          started_at: 10.days.ago,
          ended_at: nil
        )
      end
      
      it 'includes rated_position with data from closed tenure' do
        maap_data = MaapSnapshot.build_maap_data_for_employee(person, organization)
        position_data = maap_data[:position] || maap_data['position']
        
        expect(position_data).to be_present
        expect(position_data).to include(
          :position_id, :manager_id, :seat_id, :employment_type, :rated_position
        )
        expect(position_data).not_to include(:official_position_rating)
        
        # Top-level should come from active tenure
        expect(position_data[:position_id]).to eq(active_tenure.position_id)
        expect(position_data[:manager_id]).to eq(active_tenure.manager_id)
        expect(position_data[:seat_id]).to eq(active_tenure.seat_id)
        expect(position_data[:employment_type]).to eq(active_tenure.employment_type)
        
        # rated_position should come from closed tenure
        rated_position = position_data[:rated_position] || position_data['rated_position']
        expect(rated_position).to be_a(Hash)
        expect(rated_position).not_to be_empty
        expect(rated_position[:seat_id] || rated_position['seat_id']).to eq(closed_tenure.seat_id)
        expect(rated_position[:manager_id] || rated_position['manager_id']).to eq(closed_tenure.manager_id)
        expect(rated_position[:position_id] || rated_position['position_id']).to eq(closed_tenure.position_id)
        expect(rated_position[:employment_type] || rated_position['employment_type']).to eq(closed_tenure.employment_type)
        expect(rated_position[:official_position_rating] || rated_position['official_position_rating']).to eq(closed_tenure.official_position_rating)
        expect(rated_position[:started_at] || rated_position['started_at']).to be_present
        expect(rated_position[:ended_at] || rated_position['ended_at']).to be_present
      end
    end
    
    context 'when there is no previous closed employment tenure' do
      let!(:active_tenure) do
        create(:employment_tenure,
          teammate: teammate,
          company: organization,
          position: position,
          manager: manager,
          seat: nil,
          employment_type: 'full_time',
          official_position_rating: nil,
          started_at: 10.days.ago,
          ended_at: nil
        )
      end
      
      it 'includes rated_position as empty hash' do
        maap_data = MaapSnapshot.build_maap_data_for_employee(person, organization)
        position_data = maap_data[:position] || maap_data['position']
        
        expect(position_data).to be_present
        expect(position_data).to include(:rated_position)
        
        rated_position = position_data[:rated_position] || position_data['rated_position']
        expect(rated_position).to be_a(Hash)
        expect(rated_position).to be_empty
      end
    end
    
    context 'when there are multiple closed tenures' do
      let!(:oldest_closed) do
        create(:employment_tenure,
          teammate: teammate,
          company: organization,
          position: position,
          manager: manager,
          seat: nil,
          employment_type: 'part_time',
          official_position_rating: 1,
          started_at: 60.days.ago,
          ended_at: 30.days.ago
        )
      end
      let!(:most_recent_closed) do
        create(:employment_tenure,
          teammate: teammate,
          company: organization,
          position: position,
          manager: manager,
          seat: nil,
          employment_type: 'full_time',
          official_position_rating: 2,
          started_at: 30.days.ago,
          ended_at: 10.days.ago
        )
      end
      let!(:active_tenure) do
        create(:employment_tenure,
          teammate: teammate,
          company: organization,
          position: position,
          manager: manager,
          seat: nil,
          employment_type: 'full_time',
          official_position_rating: nil,
          started_at: 10.days.ago,
          ended_at: nil
        )
      end
      
      it 'uses the most recent closed tenure (by ended_at DESC)' do
        maap_data = MaapSnapshot.build_maap_data_for_employee(person, organization)
        position_data = maap_data[:position] || maap_data['position']
        rated_position = position_data[:rated_position] || position_data['rated_position']
        
        expect(rated_position).not_to be_empty
        expect(rated_position[:official_position_rating] || rated_position['official_position_rating']).to eq(most_recent_closed.official_position_rating)
        expect(rated_position[:employment_type] || rated_position['employment_type']).to eq(most_recent_closed.employment_type)
        expect(rated_position[:official_position_rating] || rated_position['official_position_rating']).not_to eq(oldest_closed.official_position_rating)
      end
    end
  end
end

