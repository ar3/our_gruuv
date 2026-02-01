require 'rails_helper'

RSpec.describe OrganizationsController, type: :controller do
  let(:person) { create(:person) }
  let(:organization) { create(:organization, name: 'Test Company', type: 'Company') }
  let(:team) { create(:organization, name: 'Test Team', type: 'Team', parent: organization) }

  before do
    # Create a teammate for the person - use first organization or create one
    teammate = create(:teammate, person: person, organization: organization)
    sign_in_as_teammate(person, organization)
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
    let!(:huddle1) { create(:huddle, huddle_playbook: create(:huddle_playbook, company: organization), started_at: 1.week.ago) }
    let!(:huddle2) { create(:huddle, huddle_playbook: create(:huddle_playbook, company: team), started_at: 2.weeks.ago) }
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
      old_huddle = create(:huddle, huddle_playbook: create(:huddle_playbook, company: organization), started_at: 8.weeks.ago)
      
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
      # Use existing teammate for organization, create teammate for team
      teammate1 = person.teammates.find_by(organization: organization)
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
      
      # Use existing teammate for organization, create teammates for team
      teammate1 = person.teammates.find_by(organization: organization)
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
      huddle_playbook = create(:huddle_playbook, company: organization)
      huddle = create(:huddle, huddle_playbook: huddle_playbook)
      
      get :huddles_review, params: { id: organization.id }
      
      expect(assigns(:playbook_metrics)).to be_present
      expect(assigns(:playbook_metrics).keys).to include(huddle_playbook.id)
      
      metrics = assigns(:playbook_metrics)[huddle_playbook.id]
      expect(metrics[:display_name]).to eq(huddle_playbook.display_name)
      expect(metrics[:id]).to eq(huddle_playbook.id)
      expect(metrics[:organization_id]).to eq(huddle_playbook.company_id)
    end

    it 'handles playbook metrics without display_name errors' do
      huddle_playbook = create(:huddle_playbook, company: organization)
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

    it 'sets the session to the correct teammate for the root company' do
      patch :switch, params: { id: organization.id }
      
      root_company = organization.root_company || organization
      expected_teammate = person.teammates.find_by(organization: root_company)
      
      expect(session[:current_company_teammate_id]).to eq(expected_teammate.id)
      expect(expected_teammate).to be_a(CompanyTeammate)
    end

    it 'finds or creates a teammate for the root company' do
      root_company = organization.root_company || organization
      
      # Verify teammate exists after switch (either found or created)
      patch :switch, params: { id: organization.id }
      
      created_teammate = person.teammates.find_by(organization: root_company)
      expect(created_teammate).to be_present
      expect(created_teammate).to be_a(CompanyTeammate)
      expect(session[:current_company_teammate_id]).to eq(created_teammate.id)
    end

    it 'uses the root company when switching to a team' do
      # Create a team under the organization
      team_org = create(:organization, name: 'Test Team', type: 'Team', parent: organization)
      
      patch :switch, params: { id: team_org.id }
      
      # Should create/find teammate for the root company, not the team
      root_company = team_org.root_company || team_org
      expected_teammate = person.teammates.find_by(organization: root_company)
      
      expect(session[:current_company_teammate_id]).to eq(expected_teammate.id)
      expect(expected_teammate.organization.id).to eq(organization.id)
    end

    it 'does not create duplicate teammates when switching multiple times' do
      root_company = organization.root_company || organization
      
      # Switch once
      patch :switch, params: { id: organization.id }
      initial_count = person.teammates.where(organization: root_company).count
      
      # Switch again
      patch :switch, params: { id: organization.id }
      
      expect(person.teammates.where(organization: root_company).count).to eq(initial_count)
    end
  end

  describe 'GET #dashboard' do
    it 'redirects to about_me page' do
      teammate = person.teammates.find_by(organization: organization)
      get :dashboard, params: { id: organization.id }
      
      expect(response).to redirect_to(about_me_organization_company_teammate_path(organization, teammate))
    end

    context 'when current_company_teammate is nil' do
      before do
        session.delete(:current_company_teammate_id)
      end

      it 'redirects to root with alert' do
        get :dashboard, params: { id: organization.id }
        
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end

    context 'when current_organization is nil' do
      before do
        session.delete(:current_company_teammate_id)
      end

      it 'redirects to root' do
        get :dashboard, params: { id: organization.id }
        
        expect(response).to redirect_to(root_path)
      end
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
    let!(:certifier) { create(:person) }
    let(:certifier_teammate) { create(:teammate, person: certifier, organization: organization) }
    let!(:teammate_milestone) { create(:teammate_milestone, teammate: person.teammates.find_by(organization: organization), ability: ability, certifying_teammate: certifier_teammate, attained_at: 30.days.ago) }

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
      create(:teammate_milestone, teammate: other_teammate, ability: other_ability, certifying_teammate: certifier_teammate, attained_at: 30.days.ago)
      
      # Create an old milestone outside the 90-day range with a different ability
      old_ability = create(:ability, organization: organization, created_by: person, updated_by: person)
      teammate = person.teammates.find_by(organization: organization)
      create(:teammate_milestone, teammate: teammate, ability: old_ability, certifying_teammate: certifier_teammate, attained_at: 100.days.ago)
      
      get :celebrate_milestones, params: { id: organization.id }
      
      expect(assigns(:total_milestones)).to eq(1) # Only the recent milestone in this organization
      expect(assigns(:unique_people)).to eq(1)
    end
  end

  describe 'POST #refresh_slack_profiles' do
    let(:slack_config) { create(:slack_configuration, organization: organization) }
    let(:mock_slack_service) { instance_double(SlackService) }
    let(:mock_matcher_service) { instance_double(SlackProfileMatcherService) }

    before do
      slack_config
      allow(SlackService).to receive(:new).with(kind_of(Organization)).and_return(mock_slack_service)
      allow(SlackProfileMatcherService).to receive(:new).and_return(mock_matcher_service)
    end

    context 'when user has employment management permissions' do
      before do
        teammate = person.teammates.find_by(organization: organization)
        teammate.update!(can_manage_employment: true)
      end

      context 'when matching is successful' do
        before do
          allow(mock_matcher_service).to receive(:call).with(kind_of(Organization)).and_return({
            success: true,
            matched_count: 5,
            total_teammates: 10,
            errors: []
          })
        end

        it 'redirects with success notice' do
          post :refresh_slack_profiles, params: { id: organization.id }
          expect(response).to redirect_to(organization_slack_path(organization))
          expect(flash[:notice]).to include('Successfully matched 5 out of 10 teammates')
        end
      end

      context 'when matching has errors' do
        before do
          allow(mock_matcher_service).to receive(:call).with(kind_of(Organization)).and_return({
            success: true,
            matched_count: 3,
            total_teammates: 10,
            errors: ['Error 1', 'Error 2']
          })
        end

        it 'redirects with notice including error count' do
          post :refresh_slack_profiles, params: { id: organization.id }
          expect(response).to redirect_to(organization_slack_path(organization))
          expect(flash[:notice]).to include('2 errors occurred')
        end
      end

      context 'when matching fails' do
        before do
          allow(mock_matcher_service).to receive(:call).with(kind_of(Organization)).and_return({
            success: false,
            error: 'Slack not configured'
          })
        end

        it 'redirects with error alert' do
          post :refresh_slack_profiles, params: { id: organization.id }
          expect(response).to redirect_to(organization_slack_path(organization))
          expect(flash[:alert]).to include('Failed to refresh Slack profiles')
          expect(flash[:alert]).to include('Slack not configured')
        end
      end
    end

    context 'when user does not have employment management permissions' do
      before do
        teammate = person.teammates.find_by(organization: organization)
        teammate.update!(can_manage_employment: false)
      end

      it 'redirects with authorization error' do
        post :refresh_slack_profiles, params: { id: organization.id }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end
  end
end
