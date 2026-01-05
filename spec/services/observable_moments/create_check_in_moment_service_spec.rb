require 'rails_helper'

RSpec.describe ObservableMoments::CreateCheckInMomentService do
  let(:company) { create(:organization, :company) }
  let(:teammate) { create(:teammate, organization: company) }
  let(:finalized_by) { create(:person) }
  let(:finalizer_teammate) { create(:teammate, organization: company, person: finalized_by) }
  
  describe '.call for PositionCheckIn' do
    let(:employment_tenure) { create(:employment_tenure, teammate: teammate, company: company) }
    
    context 'when rating improved' do
      let!(:previous_check_in) do
        create(:position_check_in,
               teammate: teammate,
               employment_tenure: employment_tenure,
               official_rating: 1,
               official_check_in_completed_at: 1.month.ago,
               finalized_by: finalized_by)
      end
      
      let(:current_check_in) do
        create(:position_check_in,
               teammate: teammate,
               employment_tenure: employment_tenure,
               official_rating: 2,
               official_check_in_completed_at: Time.current,
               finalized_by: finalized_by)
      end
      
      it 'creates observable moment when rating improved' do
        result = ObservableMoments::CreateCheckInMomentService.call(
          check_in: current_check_in,
          finalized_by: finalized_by
        )
        
        expect(result.ok?).to be true
        moment = result.value
        expect(moment.moment_type).to eq('check_in_completed')
        expect(moment.momentable).to eq(current_check_in)
        expect(moment.primary_potential_observer).to eq(finalizer_teammate)
        expect(moment.metadata['official_rating']).to eq('2')
        expect(moment.metadata['previous_rating']).to eq('1')
      end
    end
    
    context 'when rating did not improve' do
      let!(:previous_check_in) do
        create(:position_check_in,
               teammate: teammate,
               employment_tenure: employment_tenure,
               official_rating: 2,
               official_check_in_completed_at: 1.month.ago,
               finalized_by: finalized_by)
      end
      
      let(:current_check_in) do
        create(:position_check_in,
               teammate: teammate,
               employment_tenure: employment_tenure,
               official_rating: 1,
               official_check_in_completed_at: Time.current,
               finalized_by: finalized_by)
      end
      
      it 'does not create observable moment when rating decreased' do
        result = ObservableMoments::CreateCheckInMomentService.call(
          check_in: current_check_in,
          finalized_by: finalized_by
        )
        
        expect(result.ok?).to be false
        expect(result.error).to include('Rating did not improve')
      end
      
      it 'does not create observable moment when rating stayed same' do
        previous_check_in.update!(official_rating: 2)
        current_check_in.update!(official_rating: 2)
        
        result = ObservableMoments::CreateCheckInMomentService.call(
          check_in: current_check_in,
          finalized_by: finalized_by
        )
        
        expect(result.ok?).to be false
      end
    end
    
    context 'when this is the first check-in' do
      let(:first_check_in) do
        create(:position_check_in,
               teammate: teammate,
               employment_tenure: employment_tenure,
               official_rating: 2,
               official_check_in_completed_at: Time.current,
               finalized_by: finalized_by)
      end
      
      it 'creates observable moment for first check-in' do
        result = ObservableMoments::CreateCheckInMomentService.call(
          check_in: first_check_in,
          finalized_by: finalized_by
        )
        
        expect(result.ok?).to be true
      end
    end
  end
  
  describe '.call for AssignmentCheckIn' do
    let(:assignment) { create(:assignment, company: company) }
    
    context 'when rating improved' do
      let!(:previous_check_in) do
        create(:assignment_check_in,
               teammate: teammate,
               assignment: assignment,
               official_rating: 'working_to_meet',
               official_check_in_completed_at: 1.month.ago,
               finalized_by: finalized_by)
      end
      
      let(:current_check_in) do
        create(:assignment_check_in,
               teammate: teammate,
               assignment: assignment,
               official_rating: 'meeting',
               official_check_in_completed_at: Time.current,
               finalized_by: finalized_by)
      end
      
      it 'creates observable moment when rating improved' do
        result = ObservableMoments::CreateCheckInMomentService.call(
          check_in: current_check_in,
          finalized_by: finalized_by
        )
        
        expect(result.ok?).to be true
        moment = result.value
        expect(moment.moment_type).to eq('check_in_completed')
        expect(moment.metadata['check_in_type']).to include('Assignment')
      end
    end
    
    context 'when rating did not improve' do
      let!(:previous_check_in) do
        create(:assignment_check_in,
               teammate: teammate,
               assignment: assignment,
               official_rating: 'exceeding',
               official_check_in_completed_at: 1.month.ago,
               finalized_by: finalized_by)
      end
      
      let(:current_check_in) do
        create(:assignment_check_in,
               teammate: teammate,
               assignment: assignment,
               official_rating: 'meeting',
               official_check_in_completed_at: Time.current,
               finalized_by: finalized_by)
      end
      
      it 'does not create observable moment when rating decreased' do
        result = ObservableMoments::CreateCheckInMomentService.call(
          check_in: current_check_in,
          finalized_by: finalized_by
        )
        
        expect(result.ok?).to be false
      end
    end
  end
  
  describe '.call for AspirationCheckIn' do
    let(:aspiration) { create(:aspiration, organization: company) }
    
    context 'when rating improved' do
      let!(:previous_check_in) do
        create(:aspiration_check_in,
               teammate: teammate,
               aspiration: aspiration,
               official_rating: 'working_to_meet',
               official_check_in_completed_at: 1.month.ago,
               finalized_by: finalized_by)
      end
      
      let(:current_check_in) do
        create(:aspiration_check_in,
               teammate: teammate,
               aspiration: aspiration,
               official_rating: 'exceeding',
               official_check_in_completed_at: Time.current,
               finalized_by: finalized_by)
      end
      
      it 'creates observable moment when rating improved' do
        result = ObservableMoments::CreateCheckInMomentService.call(
          check_in: current_check_in,
          finalized_by: finalized_by
        )
        
        expect(result.ok?).to be true
        moment = result.value
        expect(moment.moment_type).to eq('check_in_completed')
        expect(moment.metadata['check_in_type']).to include('Aspiration')
      end
    end
  end
end

