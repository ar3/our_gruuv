require 'rails_helper'

RSpec.describe OrganizationsController, type: :controller do
  let(:person) { create(:person) }
  let(:organization) { create(:organization, name: 'Test Company', type: 'Company') }
  let(:team) { create(:organization, name: 'Test Team', type: 'Team', parent: organization) }

  before do
    session[:current_person_id] = person.id
  end

  describe 'GET #index' do
    it 'returns http success' do
      get :index
      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET #show' do
    it 'returns http success' do
      get :show, params: { id: organization.id }
      expect(response).to have_http_status(:success)
    end
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

    it 'calculates distinct participant names using display_name method and prevents duplicates' do
      # Create participants for the huddles - same person in both huddles
      participant1 = create(:huddle_participant, huddle: huddle1, person: person)
      participant2 = create(:huddle_participant, huddle: huddle2, person: person)
      
      get :huddles_review, params: { id: organization.id }
      
      metrics = assigns(:overall_metrics)
      expect(metrics[:distinct_participant_count]).to eq(1) # Same person in both huddles
      expect(metrics[:distinct_participant_names]).to eq([person.display_name])
      expect(metrics[:distinct_participant_names].length).to eq(1) # Ensure no duplicates
    end

    it 'handles multiple distinct participants correctly and prevents duplicates' do
      # Create a second person
      person2 = create(:person, first_name: 'Jane', last_name: 'Doe', email: 'jane@example.com')
      
      # Create participants for the huddles - person1 in both huddles, person2 only in huddle2
      participant1 = create(:huddle_participant, huddle: huddle1, person: person)
      participant2 = create(:huddle_participant, huddle: huddle2, person: person) # Same person again
      participant3 = create(:huddle_participant, huddle: huddle2, person: person2) # Different person
      
      get :huddles_review, params: { id: organization.id }
      
      metrics = assigns(:overall_metrics)
      expect(metrics[:distinct_participant_count]).to eq(2) # Should only count unique people
      expect(metrics[:distinct_participant_names]).to eq([person.display_name, person2.display_name].sort)
      expect(metrics[:distinct_participant_names].length).to eq(2) # Ensure no duplicates
      # Check that each name appears only once in the array
      expect(metrics[:distinct_participant_names].count(person.display_name)).to eq(1)
      expect(metrics[:distinct_participant_names].count(person2.display_name)).to eq(1)
    end

    it 'assigns playbook metrics correctly' do
      huddle_playbook = create(:huddle_playbook, organization: organization)
      huddle = create(:huddle, huddle_playbook: huddle_playbook, organization: organization)
      
      get :huddles_review, params: { id: organization.id }
      
      expect(assigns(:playbook_metrics)).to be_present
      expect(assigns(:playbook_metrics).keys).to include(huddle_playbook.id)
      
      metrics = assigns(:playbook_metrics)[huddle_playbook.id]
      expect(metrics[:display_name]).to eq(huddle_playbook.display_name)
      expect(metrics[:id]).to eq(huddle_playbook.id)
      expect(metrics[:organization_id]).to eq(huddle_playbook.organization_id)
    end

    it 'handles playbook metrics without display_name errors' do
      huddle_playbook = create(:huddle_playbook, organization: organization)
      huddle = create(:huddle, huddle_playbook: huddle_playbook, organization: organization)
      
      expect {
        get :huddles_review, params: { id: organization.id }
      }.not_to raise_error
      
      expect(response).to have_http_status(:success)
    end
  end
end 