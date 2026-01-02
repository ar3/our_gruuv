require 'rails_helper'

RSpec.describe Finalizers::PositionCheckInFinalizer do
  include ActiveSupport::Testing::TimeHelpers
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:manager) { create(:person) }
  let(:manager_teammate) { CompanyTeammate.create!(person: manager, organization: organization) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:employment_tenure) { create(:employment_tenure, teammate: teammate, company: organization, manager_teammate: manager_teammate) }
  let(:check_in) { create(:position_check_in, :ready_for_finalization, teammate: teammate, employment_tenure: employment_tenure) }
  let(:finalizer) { described_class.new(check_in: check_in, official_rating: 2, shared_notes: 'Great work!', finalized_by: manager) }

  describe '#finalize' do
    context 'when check-in is ready for finalization' do
      it 'closes current tenure with official rating' do
        travel_to Time.current do
          result = finalizer.finalize
          expect(result.ok?).to be true
          
          employment_tenure.reload
          expect(employment_tenure.ended_at).to be_within(1.second).of(Time.current)
          expect(employment_tenure.official_position_rating).to eq(2)
        end
      end

      it 'creates new tenure with same values but nil rating' do
        travel_to Time.current do
          result = finalizer.finalize
          expect(result.ok?).to be true
          
          new_tenure = result.value[:new_tenure]
          expect(new_tenure.teammate).to eq(teammate)
          expect(new_tenure.company).to eq(organization)
          expect(new_tenure.position).to eq(employment_tenure.position)
          expect(new_tenure.manager_teammate).to eq(manager_teammate)
          expect(new_tenure.seat).to eq(employment_tenure.seat)
          expect(new_tenure.employment_type).to eq(employment_tenure.employment_type)
          expect(new_tenure.started_at).to be_within(1.second).of(Time.current)
          expect(new_tenure.official_position_rating).to be_nil
        end
      end

      it 'finalizes the check-in' do
        travel_to Time.current do
          result = finalizer.finalize
          expect(result.ok?).to be true
          
          check_in.reload
          expect(check_in.official_rating).to eq(2)
          expect(check_in.shared_notes).to eq('Great work!')
          expect(check_in.official_check_in_completed_at).to eq(Time.current)
          expect(check_in.finalized_by).to eq(manager)
        end
      end

      it 'returns rating data for snapshot' do
        travel_to Time.current do
          result = finalizer.finalize
          expect(result.ok?).to be true
          
          rating_data = result.value[:rating_data]
          expect(rating_data[:position_id]).to eq(employment_tenure.position_id)
          expect(rating_data[:manager_teammate_id]).to eq(manager_teammate.id)
          expect(rating_data[:official_rating]).to eq(2)
          expect(rating_data[:rated_at]).to eq(Time.current.to_s)
        end
      end
    end

    context 'when check-in is not ready for finalization' do
      let(:check_in) { create(:position_check_in, teammate: teammate, employment_tenure: employment_tenure) }

      it 'returns error' do
        result = finalizer.finalize
        expect(result.ok?).to be false
        expect(result.error).to eq("Check-in not ready")
      end
    end

    context 'when official rating is nil' do
      let(:finalizer) { described_class.new(check_in: check_in, official_rating: nil, shared_notes: 'Notes', finalized_by: manager) }

      it 'returns error' do
        result = finalizer.finalize
        expect(result.ok?).to be false
        expect(result.error).to eq("Official rating required")
      end
    end

    context 'when official rating is 0' do
      let(:finalizer) { described_class.new(check_in: check_in, official_rating: 0, shared_notes: 'Notes', finalized_by: manager) }

      it 'returns error' do
        result = finalizer.finalize
        expect(result.ok?).to be false
        expect(result.error).to eq("Invalid official rating")
      end
    end
  end
end




