require 'rails_helper'

RSpec.describe Organizations::CompanyTeammates::GoalCheckInsController, type: :controller do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { person.teammates.find_or_create_by(organization: organization) }
  
  before do
    sign_in_as_teammate(person, organization)
  end
  
  describe 'GET #show' do
    let!(:goal1) do
      create(:goal,
        creator: teammate,
        owner: teammate,
        company: organization,
        started_at: 1.week.ago,
        most_likely_target_date: Date.today + 1.month
      )
    end
    
    let!(:goal2) do
      create(:goal,
        creator: teammate,
        owner: teammate,
        company: organization,
        started_at: 2.weeks.ago,
        most_likely_target_date: Date.today + 2.months
      )
    end
    
    let!(:goal_without_start) do
      create(:goal,
        creator: teammate,
        owner: teammate,
        company: organization,
        started_at: nil,
        most_likely_target_date: Date.today + 3.months
      )
    end
    
    let!(:completed_goal) do
      create(:goal,
        creator: teammate,
        owner: teammate,
        company: organization,
        started_at: 1.week.ago,
        completed_at: 1.day.ago,
        most_likely_target_date: Date.today + 1.month
      )
    end
    
    let!(:goal_owned_by_other) do
      other_teammate = create(:teammate, person: create(:person), organization: organization)
      create(:goal,
        creator: other_teammate,
        owner: other_teammate,
        company: organization,
        started_at: 1.week.ago,
        most_likely_target_date: Date.today + 1.month
      )
    end
    
    it 'loads all goals where teammate is owner, has start date, and no completed date' do
      get :show, params: { organization_id: organization.id, company_teammate_id: teammate.id }
      
      expect(response).to have_http_status(:success)
      expect(assigns(:goals)).to include(goal1, goal2)
      expect(assigns(:goals)).not_to include(goal_without_start)
      expect(assigns(:goals)).not_to include(completed_goal)
      expect(assigns(:goals)).not_to include(goal_owned_by_other)
    end
    
    it 'includes goals without most_likely_target_date' do
      goal_no_target = create(:goal,
        creator: teammate,
        owner: teammate,
        company: organization,
        started_at: 1.week.ago,
        most_likely_target_date: nil
      )
      
      get :show, params: { organization_id: organization.id, company_teammate_id: teammate.id }
      
      expect(assigns(:goals)).to include(goal_no_target)
    end
    
    it 'includes inspirational_objective goals' do
      inspirational_goal = create(:goal,
        creator: teammate,
        owner: teammate,
        company: organization,
        started_at: 1.week.ago,
        goal_type: 'inspirational_objective',
        most_likely_target_date: Date.today + 1.month
      )
      
      get :show, params: { organization_id: organization.id, company_teammate_id: teammate.id }
      
      expect(assigns(:goals)).to include(inspirational_goal)
    end
  end
  
  describe 'PATCH #update' do
    let!(:goal) do
      create(:goal,
        creator: teammate,
        owner: teammate,
        company: organization,
        started_at: 1.week.ago,
        most_likely_target_date: Date.today + 1.month
      )
    end
    
    it 'updates check-ins and target dates' do
      new_target_date = Date.today + 60.days
      
      patch :update, params: {
        organization_id: organization.id,
        company_teammate_id: teammate.id,
        goal_check_ins: {
          goal.id => {
            confidence_percentage: '75',
            confidence_reason: 'Making progress',
            most_likely_target_date: new_target_date.to_s
          }
        }
      }
      
      expect(response).to redirect_to(organization_company_teammate_check_ins_path(organization, teammate))
      expect(flash[:notice]).to include('Successfully saved')
      
      goal.reload
      expect(goal.most_likely_target_date).to eq(new_target_date)
      
      check_in = GoalCheckIn.find_by(goal: goal, check_in_week_start: Date.current.beginning_of_week(:monday))
      expect(check_in).to be_present
      expect(check_in.confidence_percentage).to eq(75)
      expect(check_in.confidence_reason).to eq('Making progress')
    end
  end
end

