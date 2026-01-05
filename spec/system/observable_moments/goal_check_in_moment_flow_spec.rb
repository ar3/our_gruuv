require 'rails_helper'

RSpec.describe 'Goal Check-In Observable Moment Flow', type: :system do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, organization: company, person: person) }
  let(:goal) { create(:goal, owner: teammate, company: company, started_at: Time.current) }
  
  before do
    sign_in_as(person, company)
  end
  
  describe 'confidence delta detection' do
    it 'creates moment when confidence changed by 25 points' do
      # Create previous check-in
      previous_check_in = create(:goal_check_in,
                                 goal: goal,
                                 confidence_percentage: 50,
                                 check_in_week_start: 2.weeks.ago.beginning_of_week(:monday),
                                 confidence_reporter: person)
      
      # Update check-in with significant change
      current_check_in = create(:goal_check_in,
                                goal: goal,
                                confidence_percentage: 75,
                                check_in_week_start: Date.current.beginning_of_week(:monday),
                                confidence_reporter: person)
      
      # Call service (normally done through controller)
      ObservableMoments::CreateGoalCheckInMomentService.call(
        goal_check_in: current_check_in,
        created_by: person
      )
      
      # Check that observable moment was created
      moment = ObservableMoment.last
      expect(moment).to be_present
      expect(moment.moment_type).to eq('goal_check_in')
      expect(moment.metadata['confidence_delta']).to eq(25)
      
      # Visit dashboard
      visit get_shit_done_organization_path(company)
      expect(page).to have_content('Goal Check-In')
    end
    
    it 'does not create moment when confidence changed by only 15 points' do
      previous_check_in = create(:goal_check_in,
                                 goal: goal,
                                 confidence_percentage: 50,
                                 check_in_week_start: 2.weeks.ago.beginning_of_week(:monday),
                                 confidence_reporter: person)
      
      current_check_in = create(:goal_check_in,
                                goal: goal,
                                confidence_percentage: 65,
                                check_in_week_start: Date.current.beginning_of_week(:monday),
                                confidence_reporter: person)
      
      initial_count = ObservableMoment.count
      
      ObservableMoments::CreateGoalCheckInMomentService.call(
        goal_check_in: current_check_in,
        created_by: person
      )
      
      # Should not create observable moment
      expect(ObservableMoment.count).to eq(initial_count)
    end
  end
end

