require 'rails_helper'

RSpec.describe ObservableMoments::CreateGoalCheckInMomentService do
  let(:company) { create(:organization, :company) }
  let(:goal_owner) { create(:teammate, organization: company) }
  let(:goal) { create(:goal, owner: goal_owner, company: company) }
  let(:confidence_reporter) { create(:person) }
  let!(:reporter_teammate) { create(:teammate, organization: company, person: confidence_reporter) }
  let(:created_by) { confidence_reporter }
  
  describe '.call' do
    context 'when confidence changed by 20+ percentage points' do
      let!(:previous_check_in) do
        create(:goal_check_in,
               goal: goal,
               confidence_reporter: confidence_reporter,
               confidence_percentage: 50,
               check_in_week_start: 2.weeks.ago.beginning_of_week(:monday))
      end
      
      let(:current_check_in) do
        create(:goal_check_in,
               goal: goal,
               confidence_reporter: confidence_reporter,
               confidence_percentage: 75,
               check_in_week_start: Date.current.beginning_of_week(:monday))
      end
      
      it 'creates observable moment when confidence increased by 25 points' do
        result = ObservableMoments::CreateGoalCheckInMomentService.call(
          goal_check_in: current_check_in,
          created_by: created_by
        )
        
        expect(result.ok?).to be true
        moment = result.value
        expect(moment.moment_type).to eq('goal_check_in')
        expect(moment.momentable).to eq(current_check_in)
        expect(moment.primary_potential_observer).to be_a(Teammate)
        expect(moment.primary_potential_observer.id).to eq(reporter_teammate.id)
        expect(moment.metadata['confidence_percentage']).to eq(75)
        expect(moment.metadata['previous_confidence_percentage']).to eq(50)
        expect(moment.metadata['confidence_delta']).to eq(25)
      end
      
      it 'creates observable moment when confidence decreased by 25 points' do
        previous_check_in.update!(confidence_percentage: 75)
        current_check_in.update!(confidence_percentage: 50)
        
        result = ObservableMoments::CreateGoalCheckInMomentService.call(
          goal_check_in: current_check_in,
          created_by: created_by
        )
        
        expect(result.ok?).to be true
        expect(result.value.metadata['confidence_delta']).to eq(-25)
      end
    end
    
    context 'when confidence changed by less than 20 points' do
      let!(:previous_check_in) do
        create(:goal_check_in,
               goal: goal,
               confidence_reporter: confidence_reporter,
               confidence_percentage: 50,
               check_in_week_start: 2.weeks.ago.beginning_of_week(:monday))
      end
      
      let(:current_check_in) do
        create(:goal_check_in,
               goal: goal,
               confidence_reporter: confidence_reporter,
               confidence_percentage: 65,
               check_in_week_start: Date.current.beginning_of_week(:monday))
      end
      
      it 'does not create observable moment when change is only 15 points' do
        result = ObservableMoments::CreateGoalCheckInMomentService.call(
          goal_check_in: current_check_in,
          created_by: created_by
        )
        
        expect(result.ok?).to be false
        expect(result.error).to include('Confidence change too small')
      end
    end
    
    context 'when this is the first check-in' do
      let(:first_check_in) do
        create(:goal_check_in,
               goal: goal,
               confidence_reporter: confidence_reporter,
               confidence_percentage: 75,
               check_in_week_start: Date.current.beginning_of_week(:monday))
      end
      
      it 'does not create observable moment for first check-in' do
        result = ObservableMoments::CreateGoalCheckInMomentService.call(
          goal_check_in: first_check_in,
          created_by: created_by
        )
        
        expect(result.ok?).to be false
        expect(result.error).to include('Confidence change too small')
      end
    end
    
    context 'when confidence is exactly 20 points different' do
      let!(:previous_check_in) do
        create(:goal_check_in,
               goal: goal,
               confidence_reporter: confidence_reporter,
               confidence_percentage: 50,
               check_in_week_start: 2.weeks.ago.beginning_of_week(:monday))
      end
      
      let(:current_check_in) do
        create(:goal_check_in,
               goal: goal,
               confidence_reporter: confidence_reporter,
               confidence_percentage: 70,
               check_in_week_start: Date.current.beginning_of_week(:monday))
      end
      
      it 'creates observable moment when change is exactly 20 points' do
        result = ObservableMoments::CreateGoalCheckInMomentService.call(
          goal_check_in: current_check_in,
          created_by: created_by
        )
        
        expect(result.ok?).to be true
        expect(result.value.metadata['confidence_delta']).to eq(20)
      end
    end
  end
end

