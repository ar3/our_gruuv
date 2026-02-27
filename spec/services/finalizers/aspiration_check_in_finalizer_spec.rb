require 'rails_helper'

RSpec.describe Finalizers::AspirationCheckInFinalizer do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:aspiration) { create(:aspiration, company: organization) }
  let(:finalized_by_person) { create(:person) }
  let(:finalized_by) { create(:teammate, person: finalized_by_person, organization: organization).reload.becomes(CompanyTeammate) }
  let(:finalizer_teammate) { finalized_by }
  
  let(:check_in) do
    create(:aspiration_check_in,
           :ready_for_finalization,
           teammate: teammate,
           aspiration: aspiration,
           employee_rating: 'meeting',
           manager_rating: 'exceeding',
           employee_private_notes: 'Employee notes',
           manager_private_notes: 'Manager notes')
  end
  
  let(:finalizer) do
    described_class.new(
      check_in: check_in,
      official_rating: 'exceeding',
      shared_notes: 'Great progress on this aspiration!',
      finalized_by: finalized_by
    )
  end
  
  describe '#finalize' do
    context 'when check-in is ready for finalization' do
      it 'returns success result' do
        result = finalizer.finalize
        
        expect(result).to be_ok
        expect(result.value[:check_in]).to eq(check_in)
      end
      
      it 'updates check-in with finalization data' do
        finalizer.finalize
        
        check_in.reload
        expect(check_in.official_rating).to eq('exceeding')
        expect(check_in.shared_notes).to eq('Great progress on this aspiration!')
        expect(check_in.official_check_in_completed_at).to be_present
        expect(check_in.finalized_by_teammate).to eq(finalized_by)
      end
      
      it 'returns rating data for snapshot' do
        result = finalizer.finalize
        
        expect(result.value[:rating_data]).to eq({
          aspiration_id: aspiration.id,
          official_rating: 'exceeding',
          rated_at: Date.current.to_s
        })
      end
      
      context 'when rating improved' do
        let!(:previous_check_in) do
          create(:aspiration_check_in,
                 teammate: teammate,
                 aspiration: aspiration,
                 official_rating: 'working_to_meet',
                 official_check_in_completed_at: 1.month.ago,
                 finalized_by_teammate: finalized_by)
        end
        
        it 'does not create observable moment (aspiration check-ins no longer create moments)' do
          finalizer_teammate # Ensure finalizer has a teammate in the organization

          expect {
            finalizer.finalize
          }.not_to change { ObservableMoment.count }
        end
      end
      
      context 'when rating did not improve' do
        let!(:previous_check_in) do
          create(:aspiration_check_in,
                 teammate: teammate,
                 aspiration: aspiration,
                 official_rating: 'exceeding',
                 official_check_in_completed_at: 1.month.ago,
                 finalized_by_teammate: finalized_by)
        end
        
        it 'does not create observable moment when rating stayed same' do
          expect {
            finalizer.finalize
          }.not_to change { ObservableMoment.count }
        end
      end
    end
    
    context 'when check-in is not ready for finalization' do
      before do
        check_in.update!(employee_completed_at: nil)
      end
      
      it 'returns error result' do
        result = finalizer.finalize
        
        expect(result.ok?).to be false
        expect(result.error).to eq('Check-in not ready')
      end
    end
    
    context 'when official rating is nil' do
      let(:finalizer) do
        described_class.new(
          check_in: check_in,
          official_rating: nil,
          shared_notes: 'Notes',
          finalized_by: finalized_by
        )
      end
      
      it 'returns error result' do
        result = finalizer.finalize
        
        expect(result.ok?).to be false
        expect(result.error).to eq('Official rating required')
      end
    end
  end
end
