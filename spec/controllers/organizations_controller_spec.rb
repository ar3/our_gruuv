require 'rails_helper'

RSpec.describe OrganizationsController, type: :controller do
  let(:person) { create(:person) }
  let(:organization) { create(:organization, name: 'Test Company', type: 'Company') }
  let(:team) { create(:organization, name: 'Test Team', type: 'Team', parent: organization) }

  before do
    session[:current_person_id] = person.id
  end

  describe 'GET #huddles_review' do
    let!(:huddle1) { create(:huddle, organization: organization, started_at: 1.week.ago) }
    let!(:huddle2) { create(:huddle, organization: team, started_at: 2.weeks.ago) }
    let!(:feedback1) { create(:huddle_feedback, huddle: huddle1, informed_rating: 4, connected_rating: 4, goals_rating: 4, valuable_rating: 4) }
    let!(:feedback2) { create(:huddle_feedback, huddle: huddle2, informed_rating: 5, connected_rating: 5, goals_rating: 5, valuable_rating: 5) }

    it 'returns http success' do
      get :huddles_review, params: { id: organization.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns the correct variables' do
      get :huddles_review, params: { id: organization.id }
      
      expect(assigns(:organization).id).to eq(organization.id)
      expect(assigns(:huddles)).to include(huddle1, huddle2)
      expect(assigns(:overall_metrics)).to be_present
      expect(assigns(:weekly_metrics)).to be_present
      expect(assigns(:chart_data)).to be_present
      expect(assigns(:playbook_metrics)).to be_present
    end

    it 'includes huddles from child organizations' do
      get :huddles_review, params: { id: organization.id }
      
      expect(assigns(:hierarchy_organizations).map(&:id)).to include(organization.id, team.id)
      expect(assigns(:huddles)).to include(huddle1, huddle2)
    end

    it 'filters by date range' do
      old_huddle = create(:huddle, organization: organization, started_at: 8.weeks.ago)
      
      get :huddles_review, params: { 
        id: organization.id, 
        start_date: 6.weeks.ago.to_date, 
        end_date: Date.current 
      }
      
      expect(assigns(:huddles)).to include(huddle1, huddle2)
      expect(assigns(:huddles)).not_to include(old_huddle)
    end

    it 'calculates correct metrics' do
      get :huddles_review, params: { id: organization.id }
      
      metrics = assigns(:overall_metrics)
      expect(metrics[:total_huddles]).to eq(2)
      expect(metrics[:total_feedbacks]).to eq(2)
      expect(metrics[:average_rating]).to eq(18.0) # (16 + 20) / 2
    end
  end
end 