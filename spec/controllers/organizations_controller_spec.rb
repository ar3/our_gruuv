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

  describe 'GET #switch_page' do
    let!(:company1) { create(:organization, :company, name: 'Test Company 1') }
    let!(:company2) { create(:organization, :company, name: 'Test Company 2') }

    it 'renders successfully without NoMethodError' do
      # This test verifies that the fix works - no more NoMethodError for person.huddles
      expect {
        get :switch_page
      }.not_to raise_error
      
      expect(response).to have_http_status(:success)
    end

    it 'assigns organizations and current organization' do
      get :switch_page
      
      expect(assigns(:organizations)).to be_present
      expect(assigns(:current_organization)).to be_present
    end
  end

  describe 'GET #show' do
    it 'returns http success' do
      get :show, params: { id: organization.id }
      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET #huddles_review' do
    let!(:huddle1) { create(:huddle, huddle_playbook: create(:huddle_playbook, organization: organization), started_at: 1.week.ago) }
    let!(:huddle2) { create(:huddle, huddle_playbook: create(:huddle_playbook, organization: team), started_at: 2.weeks.ago) }
    let!(:feedback1) { create(:huddle_feedback, huddle: huddle1, informed_rating: 4, connected_rating: 4, goals_rating: 4, valuable_rating: 4) }
    let!(:feedback2) { create(:huddle_feedback, huddle: huddle2, informed_rating: 5, connected_rating: 5, goals_rating: 5, valuable_rating: 5) }

    it 'returns http success' do
      get :huddles_review, params: { id: organization.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns the correct variables' do
      get :huddles_review, params: { id: organization.id }
      
      expect(assigns(:organization).id).to eq(organization.id)
      expect(assigns(:overall_metrics)).to be_present
      expect(assigns(:weekly_metrics)).to be_present
      expect(assigns(:chart_data)).to be_present
      expect(assigns(:playbook_metrics)).to be_present
      expect(assigns(:start_date)).to be_present
      expect(assigns(:end_date)).to be_present
    end

    it 'includes huddles from child organizations' do
      get :huddles_review, params: { id: organization.id }
      
      # The service should include huddles from child organizations in the metrics
      metrics = assigns(:overall_metrics)
      expect(metrics[:total_huddles]).to eq(2) # Both huddles should be included
    end

    it 'filters by date range' do
      old_huddle = create(:huddle, huddle_playbook: create(:huddle_playbook, organization: organization), started_at: 8.weeks.ago)
      
      get :huddles_review, params: { 
        id: organization.id, 
        start_date: 6.weeks.ago.to_date, 
        end_date: Date.current 
      }
      
      # The service should filter by date range
      metrics = assigns(:overall_metrics)
      expect(metrics[:total_huddles]).to eq(2) # Should only include huddles in the date range
    end

    it 'calculates correct metrics' do
      get :huddles_review, params: { id: organization.id }
      
      metrics = assigns(:overall_metrics)
      expect(metrics[:total_huddles]).to eq(2)
      expect(metrics[:total_feedbacks]).to eq(2)
      expect(metrics[:average_rating]).to eq(18.0) # (16 + 20) / 2
    end

    it 'calculates distinct participant names using display_name method and prevents duplicates' do
      # Create teammates for the person in both organizations
      teammate1 = create(:teammate, person: person, organization: organization)
      teammate2 = create(:teammate, person: person, organization: team)
      
      # Create participants for the huddles - same person in both huddles
      participant1 = create(:huddle_participant, huddle: huddle1, teammate: teammate1)
      participant2 = create(:huddle_participant, huddle: huddle2, teammate: teammate2)
      
      get :huddles_review, params: { id: organization.id }
      
      metrics = assigns(:overall_metrics)
      expect(metrics[:distinct_participant_count]).to eq(1) # Same person in both huddles
      expect(metrics[:distinct_participant_names]).to eq([person.display_name])
      expect(metrics[:distinct_participant_names].length).to eq(1) # Ensure no duplicates
    end

    it 'handles multiple distinct participants correctly and prevents duplicates' do
      # Create a second person
      person2 = create(:person, first_name: 'Jane', last_name: 'Doe', email: 'jane@example.com')
      
      # Create teammates for both people
      teammate1 = create(:teammate, person: person, organization: organization)
      teammate2 = create(:teammate, person: person, organization: team)
      teammate3 = create(:teammate, person: person2, organization: team)
      
      # Create participants for the huddles - person1 in both huddles, person2 only in huddle2
      participant1 = create(:huddle_participant, huddle: huddle1, teammate: teammate1)
      participant2 = create(:huddle_participant, huddle: huddle2, teammate: teammate2) # Same person again
      participant3 = create(:huddle_participant, huddle: huddle2, teammate: teammate3) # Different person
      
      get :huddles_review, params: { id: organization.id }
      
      metrics = assigns(:overall_metrics)
      expect(metrics[:distinct_participant_count]).to eq(2) # person1 and person2
      expect(metrics[:distinct_participant_names]).to include(person.display_name, person2.display_name)
      expect(metrics[:distinct_participant_names].length).to eq(2) # Ensure no duplicates
    end

    it 'assigns playbook metrics correctly' do
      huddle_playbook = create(:huddle_playbook, organization: organization)
      huddle = create(:huddle, huddle_playbook: huddle_playbook)
      
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
      huddle = create(:huddle, huddle_playbook: huddle_playbook)
      
      expect {
        get :huddles_review, params: { id: organization.id }
      }.not_to raise_error
      
      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST #refresh_slack_channels' do
    context 'when organization is a company' do
      it 'redirects to huddles review with success message' do
        allow(Companies::RefreshSlackChannelsJob).to receive(:perform_and_get_result).and_return(true)
        
        post :refresh_slack_channels, params: { id: organization.id }
        
        expect(response).to redirect_to(huddles_review_organization_path(organization))
        expect(flash[:notice]).to eq('Slack channels refreshed successfully!')
      end
      
      it 'redirects to huddles review with error message on failure' do
        allow(Companies::RefreshSlackChannelsJob).to receive(:perform_and_get_result).and_return(false)
        
        post :refresh_slack_channels, params: { id: organization.id }
        
        expect(response).to redirect_to(huddles_review_organization_path(organization))
        expect(flash[:alert]).to eq('Failed to refresh Slack channels. Please check your Slack configuration.')
      end
    end
    
    context 'when organization is not a company' do
      let(:organization) { create(:organization, :team) }
      
      it 'redirects to huddles review with error message' do
        post :refresh_slack_channels, params: { id: organization.id }
        
        expect(response).to redirect_to(huddles_review_organization_path(organization))
        expect(flash[:alert]).to eq('Slack channel management is only available for companies.')
      end
    end
  end

  describe 'PATCH #update_huddle_review_channel' do
    context 'when organization is a company' do
      let(:slack_channel) { create(:third_party_object, organization: organization, third_party_source: 'slack', third_party_object_type: 'channel') }
      
      before do
        slack_channel
      end
      
      it 'updates the notification channel successfully' do
        patch :update_huddle_review_channel, params: { id: organization.id, channel_id: slack_channel.third_party_id }
        
        expect(response).to redirect_to(huddles_review_organization_path(organization))
        expect(flash[:notice]).to eq('Huddle review notification channel updated successfully!')
        
        # Check that the association was created
        organization.reload
        company = organization.becomes(Company)
        expect(company.huddle_review_notification_channel).to eq(slack_channel)
      end
      
      it 'handles invalid channel_id gracefully' do
        # Mock the save to return false for invalid channel_id
        allow_any_instance_of(Company).to receive(:save).and_return(false)
        
        patch :update_huddle_review_channel, params: { id: organization.id, channel_id: 'invalid_channel_id' }
        
        expect(response).to redirect_to(huddles_review_organization_path(organization))
        expect(flash[:alert]).to eq('Failed to update notification channel.')
      end
    end
    
    context 'when organization is not a company' do
      let(:organization) { create(:organization, :team) }
      
      it 'redirects with error message' do
        patch :update_huddle_review_channel, params: { id: organization.id, channel_id: 'some_channel_id' }
        
        expect(response).to redirect_to(huddles_review_organization_path(organization))
        expect(flash[:alert]).to eq('Channel management is only available for companies.')
      end
    end
  end

  describe 'PATCH #switch' do
    it 'switches to the selected organization and redirects to organization show page' do
      patch :switch, params: { id: organization.id }
      expect(response).to redirect_to(organization_path(organization))
      expect(flash[:notice]).to eq("Switched to #{organization.display_name}")
    end

    it 'redirects to organizations index on failure' do
      # Mock the switch_to_organization method to return false
      allow_any_instance_of(Person).to receive(:switch_to_organization).and_return(false)
      patch :switch, params: { id: organization.id }
      expect(response).to redirect_to(organizations_path)
      expect(flash[:alert]).to eq("Failed to switch organization")
    end
  end

  describe 'GET #celebrate_milestones' do
    before do
      # Temporarily disable PaperTrail for this test to avoid controller_info issues
      PaperTrail.enabled = false
    end

    after do
      # Re-enable PaperTrail after the test
      PaperTrail.enabled = true
    end

    let!(:ability) { create(:ability, organization: organization, created_by: person, updated_by: person) }
    let!(:teammate) { create(:teammate, person: person, organization: organization) }
    let!(:certifier) { create(:person) }
    let!(:person_milestone) { create(:person_milestone, teammate: teammate, ability: ability, certified_by: certifier, attained_at: 30.days.ago) }

    it 'returns http success' do
      get :celebrate_milestones, params: { id: organization.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns recent milestones without ActiveRecord::ConfigurationError' do
      expect {
        get :celebrate_milestones, params: { id: organization.id }
      }.not_to raise_error(ActiveRecord::ConfigurationError)
      
      expect(response).to have_http_status(:success)
    end

    it 'assigns the correct variables' do
      get :celebrate_milestones, params: { id: organization.id }
      
      expect(assigns(:organization).id).to eq(organization.id)
      expect(assigns(:recent_milestones)).to be_present
      expect(assigns(:milestones_by_person)).to be_present
      expect(assigns(:total_milestones)).to eq(1)
      expect(assigns(:unique_people)).to eq(1)
    end

    it 'filters milestones by organization and date range' do
      # Create a milestone in a different organization
      other_org = create(:organization)
      other_ability = create(:ability, organization: other_org)
      other_teammate = create(:teammate, person: person, organization: other_org)
      create(:person_milestone, teammate: other_teammate, ability: other_ability, certified_by: certifier, attained_at: 30.days.ago)
      
      # Create an old milestone outside the 90-day range with a different ability
      old_ability = create(:ability, organization: organization, created_by: person, updated_by: person)
      create(:person_milestone, teammate: teammate, ability: old_ability, certified_by: certifier, attained_at: 100.days.ago)
      
      get :celebrate_milestones, params: { id: organization.id }
      
      expect(assigns(:total_milestones)).to eq(1) # Only the recent milestone in this organization
      expect(assigns(:unique_people)).to eq(1)
    end
  end
end
