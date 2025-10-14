require 'rails_helper'

RSpec.describe CheckInFinalizationService do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:manager) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:employment_tenure) { create(:employment_tenure, teammate: teammate, company: organization, manager: manager) }
  let(:check_in) { create(:position_check_in, :ready_for_finalization, teammate: teammate, employment_tenure: employment_tenure) }
  let(:finalization_params) { { finalize_position: '1', position_official_rating: '2', position_shared_notes: 'Great work!' } }
  let(:request_info) { { ip_address: '127.0.0.1', user_agent: 'Test Agent' } }
  let(:service) { described_class.new(teammate: teammate, finalization_params: finalization_params, finalized_by: manager, request_info: request_info) }

  describe '#call' do
    context 'when finalizing position check-in' do
      it 'creates a MAAP snapshot' do
        result = service.call
        expect(result.success?).to be true
        
        snapshot = result.value[:snapshot]
        expect(snapshot.employee).to eq(person)
        expect(snapshot.created_by).to eq(manager)
        expect(snapshot.company).to eq(organization)
        expect(snapshot.change_type).to eq('position_check_in')
        expect(snapshot.reason).to include(person.display_name)
        expect(snapshot.effective_date).to be_present
        expect(snapshot.manager_request_info).to include(
          'finalized_by_id' => manager.id,
          'ip_address' => '127.0.0.1',
          'user_agent' => 'Test Agent'
        )
      end

      it 'includes position rating data in snapshot' do
        result = service.call
        expect(result.success?).to be true
        
        snapshot = result.value[:snapshot]
        ratings_data = snapshot.ratings_data
        expect(ratings_data['position']).to include(
          'position_id' => employment_tenure.position_id,
          'manager_id' => manager.id,
          'official_rating' => 2,
          'rated_at' => Date.current.to_s
        )
      end

      it 'includes assignment ratings in snapshot' do
        assignment_tenure = create(:assignment_tenure, teammate: teammate, anticipated_energy_percentage: 80)
        
        result = service.call
        expect(result.success?).to be true
        
        snapshot = result.value[:snapshot]
        ratings_data = snapshot.ratings_data
        expect(ratings_data['assignments']).to be_an(Array)
        expect(ratings_data['assignments'].first).to include(
          'assignment_id' => assignment_tenure.assignment_id,
          'anticipated_energy' => 80
        )
      end

      it 'includes milestone attainments in snapshot' do
        milestone = create(:teammate_milestone, teammate: teammate, milestone_level: 3)
        
        result = service.call
        expect(result.success?).to be true
        
        snapshot = result.value[:snapshot]
        ratings_data = snapshot.ratings_data
        expect(ratings_data['milestones']).to be_an(Array)
        expect(ratings_data['milestones'].first).to include(
          'ability_id' => milestone.ability_id,
          'milestone_level' => 3
        )
      end

      it 'links snapshot to finalized check-in' do
        result = service.call
        expect(result.success?).to be true
        
        check_in.reload
        expect(check_in.maap_snapshot).to eq(result.value[:snapshot])
      end

      it 'returns results with position data' do
        result = service.call
        expect(result.success?).to be true
        
        results = result.value[:results]
        expect(results[:position]).to be_present
        expect(results[:position][:check_in]).to eq(check_in)
        expect(results[:position][:new_tenure]).to be_present
        expect(results[:position][:rating_data]).to be_present
      end
    end

    context 'when position check-in is not ready' do
      let(:check_in) { create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure) }

      it 'returns error' do
        result = service.call
        expect(result.success?).to be false
        expect(result.error).to eq("Position check-in not ready")
      end
    end

    context 'when no position check-in exists' do
      let(:teammate_without_check_in) { create(:teammate, person: person, organization: organization) }
      let(:service) { described_class.new(teammate: teammate_without_check_in, finalization_params: finalization_params, finalized_by: manager, request_info: request_info) }

      it 'returns error' do
        result = service.call
        expect(result.success?).to be false
        expect(result.error).to eq("Position check-in not ready")
      end
    end

    context 'when not finalizing position' do
      let(:finalization_params) { {} }

      it 'creates snapshot with empty position data' do
        result = service.call
        expect(result.success?).to be true
        
        snapshot = result.value[:snapshot]
        ratings_data = snapshot.ratings_data
        expect(ratings_data['position']).to be_nil
        expect(ratings_data['assignments']).to be_an(Array)
        expect(ratings_data['milestones']).to be_an(Array)
        expect(ratings_data['aspirations']).to be_an(Array)
      end
    end

    context 'when error occurs during finalization' do
      before do
        allow_any_instance_of(Finalizers::PositionCheckInFinalizer).to receive(:finalize).and_raise(StandardError, 'Database error')
      end

      it 'returns error with message' do
        result = service.call
        expect(result.success?).to be false
        expect(result.error).to eq("Failed to finalize check-ins: Database error")
      end
    end
  end
end




