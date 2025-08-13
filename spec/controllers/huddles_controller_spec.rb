require 'rails_helper'

RSpec.describe HuddlesController, type: :controller do
  let(:organization) { create(:organization, name: 'Test Org') }
  let!(:slack_config) { create(:slack_configuration, organization: organization) }
  let(:playbook) { create(:huddle_playbook, organization: organization) }
  let(:huddle) { create(:huddle, huddle_playbook: playbook, started_at: Time.current) }
  let(:person) { create(:person, first_name: 'John', last_name: 'Doe', email: 'john@example.com') }
  let!(:participant) { create(:huddle_participant, huddle: huddle, person: person, role: 'active') }

  before do
    session[:current_person_id] = person.id
  end

  describe 'GET #show' do
    it 'assigns the requested huddle' do
      get :show, params: { id: huddle.id }
      expect(assigns(:huddle)).to eq(huddle)
    end

    it 'redirects to join page when user is not logged in' do
      session[:current_person_id] = nil
      get :show, params: { id: huddle.id }
      expect(response).to redirect_to(join_huddle_path(huddle))
    end
  end

  describe 'GET #feedback' do
    it 'assigns the requested huddle' do
      get :feedback, params: { id: huddle.id }
      expect(assigns(:huddle)).to eq(huddle)
    end

    it 'assigns the current person' do
      get :feedback, params: { id: huddle.id }
      expect(assigns(:current_person)).to eq(person)
    end

    it 'assigns existing participant' do
      get :feedback, params: { id: huddle.id }
      expect(assigns(:existing_participant)).to eq(participant)
    end
  end

  describe 'POST #submit_feedback' do
    let(:valid_feedback_params) do
      {
        informed_rating: '4',
        connected_rating: '5',
        goals_rating: '3',
        valuable_rating: '4',
        personal_conflict_style: 'Collaborative',
        team_conflict_style: 'Compromising',
        appreciation: 'Great meeting!',
        change_suggestion: 'More time for discussion',
        private_department_head: 'Private feedback for DH',
        private_facilitator: 'Private feedback for facilitator',
        anonymous: '0'
      }
    end

    before do
      allow(Huddles::PostAnnouncementJob).to receive(:perform_and_get_result)
      allow(Huddles::PostSummaryJob).to receive(:perform_and_get_result)
      allow(Huddles::PostFeedbackJob).to receive(:perform_and_get_result)
    end

    context 'with valid parameters' do
      it 'creates a new feedback record' do
        expect {
          post :submit_feedback, params: { id: huddle.id }.merge(valid_feedback_params)
        }.to change(HuddleFeedback, :count).by(1)
      end

      it 'saves all the feedback data correctly' do
        post :submit_feedback, params: { id: huddle.id }.merge(valid_feedback_params)
        
        feedback = HuddleFeedback.last
        expect(feedback.person).to eq(person)
        expect(feedback.huddle).to eq(huddle)
        expect(feedback.informed_rating).to eq(4)
        expect(feedback.connected_rating).to eq(5)
        expect(feedback.goals_rating).to eq(3)
        expect(feedback.valuable_rating).to eq(4)
        expect(feedback.personal_conflict_style).to eq('Collaborative')
        expect(feedback.team_conflict_style).to eq('Compromising')
        expect(feedback.appreciation).to eq('Great meeting!')
        expect(feedback.change_suggestion).to eq('More time for discussion')
        expect(feedback.private_department_head).to eq('Private feedback for DH')
        expect(feedback.private_facilitator).to eq('Private feedback for facilitator')
        expect(feedback.anonymous).to be false
      end

      it 'calls PostAnnouncementJob.perform_and_get_result when creating new feedback' do
        post :submit_feedback, params: { id: huddle.id }.merge(valid_feedback_params)
        
        expect(Huddles::PostAnnouncementJob).to have_received(:perform_and_get_result).with(huddle.id)
      end

      it 'calls PostSummaryJob.perform_and_get_result when creating new feedback' do
        post :submit_feedback, params: { id: huddle.id }.merge(valid_feedback_params)
        
        expect(Huddles::PostSummaryJob).to have_received(:perform_and_get_result).with(huddle.id)
      end

      it 'calls PostFeedbackJob.perform_and_get_result when creating new feedback' do
        post :submit_feedback, params: { id: huddle.id }.merge(valid_feedback_params)
        
        feedback = HuddleFeedback.last
        expect(Huddles::PostFeedbackJob).to have_received(:perform_and_get_result).with(huddle.id, feedback.id)
      end
    end

    context 'with conflict styles only' do
      let(:conflict_only_params) do
        {
          informed_rating: '4',
          connected_rating: '5',
          goals_rating: '3',
          valuable_rating: '4',
          personal_conflict_style: 'Competing',
          team_conflict_style: 'Avoiding'
        }
      end

      it 'saves conflict styles correctly' do
        post :submit_feedback, params: { id: huddle.id }.merge(conflict_only_params)
        
        feedback = HuddleFeedback.last
        expect(feedback.personal_conflict_style).to eq('Competing')
        expect(feedback.team_conflict_style).to eq('Avoiding')
      end
    end

    context 'with anonymous feedback' do
      let(:anonymous_params) do
        valid_feedback_params.merge(anonymous: '1')
      end

      it 'saves anonymous flag correctly' do
        post :submit_feedback, params: { id: huddle.id }.merge(anonymous_params)
        
        feedback = HuddleFeedback.last
        expect(feedback.anonymous).to be true
      end
    end

    context 'when updating existing feedback' do
      let!(:existing_feedback) do
        create(:huddle_feedback, 
          huddle: huddle, 
          person: person,
          informed_rating: 3,
          connected_rating: 4,
          goals_rating: 2,
          valuable_rating: 3,
          appreciation: 'Original feedback',
          change_suggestion: 'Original suggestion'
        )
      end

      let(:updated_feedback_params) do
        {
          informed_rating: '5',
          connected_rating: '4',
          goals_rating: '5',
          valuable_rating: '4',
          personal_conflict_style: 'Collaborative',
          team_conflict_style: 'Compromising',
          appreciation: 'Updated feedback!',
          change_suggestion: 'Updated suggestion',
          private_department_head: 'Updated private feedback for DH',
          private_facilitator: 'Updated private feedback for facilitator',
          anonymous: '1'
        }
      end

      it 'updates the existing feedback record' do
        expect {
          post :submit_feedback, params: { id: huddle.id }.merge(updated_feedback_params)
        }.not_to change(HuddleFeedback, :count)
        
        existing_feedback.reload
        expect(existing_feedback.informed_rating).to eq(5)
        expect(existing_feedback.connected_rating).to eq(4)
        expect(existing_feedback.goals_rating).to eq(5)
        expect(existing_feedback.valuable_rating).to eq(4)
        expect(existing_feedback.personal_conflict_style).to eq('Collaborative')
        expect(existing_feedback.team_conflict_style).to eq('Compromising')
        expect(existing_feedback.appreciation).to eq('Updated feedback!')
        expect(existing_feedback.change_suggestion).to eq('Updated suggestion')
        expect(existing_feedback.private_department_head).to eq('Updated private feedback for DH')
        expect(existing_feedback.private_facilitator).to eq('Updated private feedback for facilitator')
        expect(existing_feedback.anonymous).to be true
      end

      it 'calls PostAnnouncementJob.perform_and_get_result when updating existing feedback' do
        post :submit_feedback, params: { id: huddle.id }.merge(updated_feedback_params)
        
        expect(Huddles::PostAnnouncementJob).to have_received(:perform_and_get_result).with(huddle.id)
      end

      it 'calls PostSummaryJob.perform_and_get_result when updating existing feedback' do
        post :submit_feedback, params: { id: huddle.id }.merge(updated_feedback_params)
        
        expect(Huddles::PostSummaryJob).to have_received(:perform_and_get_result).with(huddle.id)
      end

      it 'does not call PostFeedbackJob.perform_and_get_result when updating existing feedback' do
        post :submit_feedback, params: { id: huddle.id }.merge(updated_feedback_params)
        
        expect(Huddles::PostFeedbackJob).not_to have_received(:perform_and_get_result)
      end

      it 'redirects with success message when updating feedback' do
        post :submit_feedback, params: { id: huddle.id }.merge(updated_feedback_params)
        
        expect(response).to redirect_to(huddle_path(huddle))
        expect(flash[:notice]).to eq('Your feedback has been updated!')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          informed_rating: '6', # Invalid rating
          connected_rating: '5',
          goals_rating: '3',
          valuable_rating: '4'
        }
      end

      it 'does not create a feedback record' do
        expect {
          post :submit_feedback, params: { id: huddle.id }.merge(invalid_params)
        }.not_to change(HuddleFeedback, :count)
      end

      it 'renders feedback form with errors' do
        post :submit_feedback, params: { id: huddle.id }.merge(invalid_params)
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:feedback)
      end
    end

    context 'when user is not logged in' do
      before do
        session[:current_person_id] = nil
      end

      it 'redirects to join page' do
        post :submit_feedback, params: { id: huddle.id }.merge(valid_feedback_params)
        
        expect(response).to redirect_to(join_huddle_path(huddle))
      end
    end

    context 'when user is not a participant' do
      before do
        participant.destroy
      end

      it 'redirects to join page' do
        post :submit_feedback, params: { id: huddle.id }.merge(valid_feedback_params)
        
        expect(response).to redirect_to(join_huddle_path(huddle))
      end
    end
  end

  describe 'GET #index' do
    let(:organization) { create(:organization, :team) }
    let(:company) { organization.root_company }
    
    before do
      session[:current_person_id] = person.id
      allow(controller).to receive(:current_organization).and_return(organization)
      allow(controller).to receive(:current_person).and_return(person)
    end

    it 'renders the index view without routing errors' do
      # This test ensures that all path helpers used in the view exist
      # and that the view can render without NoMethodError exceptions
      
      # Ensure all required path helpers exist
      expect { feedback_huddle_path(1) }.not_to raise_error
      expect { join_huddle_path(1) }.not_to raise_error
      expect { new_huddle_path }.not_to raise_error
      expect { post_weekly_summary_huddles_path }.not_to raise_error
      expect { start_huddle_from_playbook_huddles_path }.not_to raise_error
      
      # Test that the view can render without errors
      expect { get :index }.not_to raise_error
      expect(response).to have_http_status(:success)
    end

    it 'catches routing errors in the view when rendering with active huddle data' do
      # This test specifically catches the type of routing error that was found in manual testing
      # where the view tries to use a non-existent path helper
      
      # Create test data that will trigger the view logic with active huddles
      playbook = create(:huddle_playbook, organization: organization)
      huddle = create(:huddle, 
        huddle_playbook: playbook, 
        started_at: Time.current.beginning_of_week(:monday) + 1.day,
        expires_at: 1.day.from_now
      )
      participant = create(:huddle_participant, huddle: huddle, person: person)
      
      # Set up the controller instance variables that the view needs
      controller.instance_variable_set(:@huddles, [])
      controller.instance_variable_set(:@recent_playbooks, [playbook])
      controller.instance_variable_set(:@weekly_summary_status, {
        has_recent_summary: false,
        last_posted_at: nil,
        slack_message_url: nil
      })
      controller.instance_variable_set(:@playbook_active_huddles, {
        playbook.id => {
          huddle: huddle,
          participant: participant,
          has_feedback: false,
          slack_message_url: nil
        }
      })
      
      # This should not raise a NoMethodError about missing path helpers
      expect { get :index }.not_to raise_error
      expect(response).to have_http_status(:success)
    end

    it 'handles active huddles data correctly' do
      # Create test data for active huddles
      playbook = create(:huddle_playbook, organization: organization)
      huddle = create(:huddle, 
        huddle_playbook: playbook, 
        started_at: Time.current.beginning_of_week(:monday) + 1.day,
        expires_at: 1.day.from_now
      )
      participant = create(:huddle_participant, huddle: huddle, person: person)
      
      expect { get :index }.not_to raise_error
      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST #post_start_announcement_to_slack' do
    let(:slack_config) { create(:slack_configuration, organization: organization) }

    before do
      slack_config
      allow(Huddles::PostAnnouncementJob).to receive(:perform_now)
    end

    it 'assigns the requested huddle' do
      post :post_start_announcement_to_slack, params: { id: huddle.id }
      expect(assigns(:huddle)).to eq(huddle)
    end

    it 'redirects to huddle page with success message when Slack is configured' do
      post :post_start_announcement_to_slack, params: { id: huddle.id }
      
      expect(response).to redirect_to(huddle_path(huddle))
      expect(flash[:notice]).to eq('Huddle start announcement posted to Slack successfully!')
    end

    it 'redirects to huddle page with error when Slack is not configured' do
      slack_config.destroy
      
      post :post_start_announcement_to_slack, params: { id: huddle.id }
      
      expect(response).to redirect_to(huddle_path(huddle))
      expect(flash[:alert]).to eq('Slack is not configured for this organization.')
    end

    it 'redirects to huddle page with error when Slack service fails' do
      allow(Huddles::PostAnnouncementJob).to receive(:perform_now).and_raise(StandardError.new('Slack error'))
      
      post :post_start_announcement_to_slack, params: { id: huddle.id }
      
      expect(response).to redirect_to(huddle_path(huddle))
      expect(flash[:alert]).to eq('Failed to post to Slack: Slack error')
    end
  end

  describe 'GET #notifications_debug' do
    it 'assigns the requested huddle' do
      get :notifications_debug, params: { id: huddle.id }
      expect(assigns(:huddle)).to eq(huddle)
    end

    it 'assigns notifications ordered by created_at desc' do
      notification1 = create(:notification, notifiable: huddle, notification_type: 'huddle_announcement', created_at: 1.hour.ago)
      notification2 = create(:notification, notifiable: huddle, notification_type: 'huddle_summary', created_at: 2.hours.ago)
      
      get :notifications_debug, params: { id: huddle.id }
      
      expect(assigns(:notifications)).to eq([notification1, notification2])
    end
  end

  describe '#find_or_create_huddle_playbook' do
    let(:organization) { create(:organization) }

    context 'when no playbook exists' do
      it 'creates a new playbook with empty string special_session_name' do
        expect {
          controller.send(:find_or_create_huddle_playbook, organization)
        }.to change(HuddlePlaybook, :count).by(1)
        
        playbook = HuddlePlaybook.last
        expect(playbook.organization_id).to eq(organization.id)
        expect(playbook.special_session_name).to eq('')
      end
    end

    context 'when playbook with empty string special_session_name exists' do
      let!(:existing_playbook) { create(:huddle_playbook, organization: organization, special_session_name: '') }

      it 'returns the existing playbook' do
        result = controller.send(:find_or_create_huddle_playbook, organization)
        expect(result).to eq(existing_playbook)
      end

      it 'does not create a new playbook' do
        expect {
          controller.send(:find_or_create_huddle_playbook, organization)
        }.not_to change(HuddlePlaybook, :count)
      end
    end

    context 'when playbook with nil special_session_name exists' do
      let!(:existing_playbook) { create(:huddle_playbook, organization: organization, special_session_name: nil) }

      it 'returns the existing playbook' do
        result = controller.send(:find_or_create_huddle_playbook, organization)
        expect(result).to eq(existing_playbook)
      end

      it 'does not create a new playbook' do
        expect {
          controller.send(:find_or_create_huddle_playbook, organization)
        }.not_to change(HuddlePlaybook, :count)
      end
    end

    context 'when playbook with whitespace-only special_session_name exists' do
      let!(:existing_playbook) { create(:huddle_playbook, organization: organization, special_session_name: '   ') }

      it 'returns the existing playbook' do
        result = controller.send(:find_or_create_huddle_playbook, organization)
        expect(result).to eq(existing_playbook)
      end

      it 'does not create a new playbook' do
        expect {
          controller.send(:find_or_create_huddle_playbook, organization)
        }.not_to change(HuddlePlaybook, :count)
      end
    end
  end

  describe 'POST #create' do
    let(:company) { create(:organization, :company) }
    let(:team) { create(:organization, :team, parent: company) }
    
    before do
      allow(controller).to receive(:find_or_create_organization).and_return(team)
      allow(controller).to receive(:get_or_create_person_from_session_or_params).and_return(person)
      allow(controller).to receive(:current_person).and_return(person)
    end

    context 'when no active huddle exists for the playbook this week' do
      it 'creates a new huddle' do
        expect {
          post :create, params: { company_selection: company.name, team_name: team.name, email: person.email }
        }.to change(Huddle, :count).by(1)
      end

      it 'creates a default huddle playbook if none exists' do
        expect {
          post :create, params: { company_selection: company.name, team_name: team.name, email: person.email }
        }.to change(HuddlePlaybook, :count).by(1)
      end

      it 'adds the creator as a facilitator participant' do
        post :create, params: { company_selection: company.name, team_name: team.name, email: person.email }
        
        huddle = Huddle.last
        participant = huddle.huddle_participants.find_by(person: person)
        expect(participant).to be_present
        expect(participant.role).to eq('facilitator')
      end

      it 'redirects to the new huddle with success message' do
        post :create, params: { company_selection: company.name, team_name: team.name, email: person.email }
        
        huddle = Huddle.last
        expect(response).to redirect_to(huddle_path(huddle))
        expect(flash[:notice]).to eq('Huddle created successfully!')
      end
    end

    context 'when an active huddle already exists for the playbook this week' do
      let!(:default_playbook) { create(:huddle_playbook, organization: team, special_session_name: '') }
      let!(:existing_huddle) do
        create(:huddle, 
          huddle_playbook: default_playbook,
          started_at: 2.days.ago,
          expires_at: 1.day.from_now
        )
      end

      it 'does not create a new huddle' do
        expect {
          post :create, params: { company_selection: company.name, team_name: team.name, email: person.email }
        }.not_to change(Huddle, :count)
      end

      it 'adds the creator as a participant to the existing huddle' do
        expect {
          post :create, params: { company_selection: company.name, team_name: team.name, email: person.email }
        }.to change(HuddleParticipant, :count).by(1)
        
        participant = existing_huddle.huddle_participants.find_by(person: person)
        expect(participant).to be_present
        expect(participant.role).to eq('facilitator')
      end

      it 'redirects to the existing huddle with a notice' do
        post :create, params: { company_selection: company.name, team_name: team.name, email: person.email }
        
        expect(response).to redirect_to(huddle_path(existing_huddle))
        expect(flash[:notice]).to eq('A huddle for this playbook is already active this week. You have been added as a participant!')
      end
    end

    context 'when an old huddle exists for the playbook (not this week)' do
      let!(:default_playbook) { create(:huddle_playbook, organization: team, special_session_name: '') }
      let!(:old_huddle) do
        create(:huddle, 
          huddle_playbook: default_playbook,
          started_at: 2.weeks.ago,
          expires_at: 1.week.ago
        )
      end

      it 'creates a new huddle' do
        expect {
          post :create, params: { company_selection: company.name, team_name: team.name, email: person.email }
        }.to change(Huddle, :count).by(1)
      end
    end
  end

  describe 'POST #start_huddle_from_playbook' do
    let(:new_playbook) { create(:huddle_playbook, organization: organization, special_session_name: 'New Session') }

    before do
      allow(Huddles::PostAnnouncementJob).to receive(:perform_now)
      allow(Huddles::PostSummaryJob).to receive(:perform_now)
    end

    context 'when no active huddle exists for the playbook this week' do
      it 'creates a new huddle for the playbook' do
        expect {
          post :start_huddle_from_playbook, params: { playbook_id: new_playbook.id }
        }.to change(Huddle, :count).by(1)
      end

      it 'posts announcements to Slack' do
        post :start_huddle_from_playbook, params: { playbook_id: new_playbook.id }
        
        expect(Huddles::PostAnnouncementJob).to have_received(:perform_now)
        expect(Huddles::PostSummaryJob).to have_received(:perform_now)
      end

      it 'redirects with success message' do
        post :start_huddle_from_playbook, params: { playbook_id: new_playbook.id }
        
        expect(response).to redirect_to(huddles_path)
        expect(flash[:notice]).to eq('Huddle started successfully! Slack notifications have been posted.')
      end
    end

    context 'when an active huddle already exists for the playbook this week' do
      let!(:existing_huddle) do
        create(:huddle, 
          huddle_playbook: new_playbook,
          started_at: 2.days.ago,
          expires_at: 1.day.from_now
        )
      end

      it 'does not create a new huddle' do
        expect {
          post :start_huddle_from_playbook, params: { playbook_id: new_playbook.id }
        }.not_to change(Huddle, :count)
      end

      it 'adds the current user as a participant to the existing huddle' do
        expect {
          post :start_huddle_from_playbook, params: { playbook_id: new_playbook.id }
        }.to change(HuddleParticipant, :count).by(1)
        
        participant = existing_huddle.huddle_participants.find_by(person: person)
        expect(participant).to be_present
        expect(participant.role).to eq('active')
      end

      it 'redirects to the existing huddle with a notice' do
        post :start_huddle_from_playbook, params: { playbook_id: new_playbook.id }
        
        expect(response).to redirect_to(huddle_path(existing_huddle))
        expect(flash[:notice]).to eq('A huddle for this playbook is already active this week. You have been added as a participant!')
      end

      it 'does not post new Slack notifications' do
        post :start_huddle_from_playbook, params: { playbook_id: new_playbook.id }
        
        expect(Huddles::PostAnnouncementJob).not_to have_received(:perform_now)
        expect(Huddles::PostSummaryJob).not_to have_received(:perform_now)
      end
    end

    context 'when an old huddle exists for the playbook (not this week)' do
      let!(:old_huddle) do
        create(:huddle, 
          huddle_playbook: new_playbook,
          started_at: 2.weeks.ago,
          expires_at: 1.week.ago
        )
      end

      it 'creates a new huddle' do
        expect {
          post :start_huddle_from_playbook, params: { playbook_id: new_playbook.id }
        }.to change(Huddle, :count).by(1)
      end
    end
  end

  describe 'POST #post_weekly_summary' do
    before do
      allow(Companies::WeeklyHuddlesReviewNotificationJob).to receive(:perform_and_get_result)
        .and_return({ success: true })
    end

    it 'calls the weekly notification job' do
      post :post_weekly_summary
      
      expect(Companies::WeeklyHuddlesReviewNotificationJob).to have_received(:perform_and_get_result)
    end

    it 'redirects with success message when job succeeds' do
      post :post_weekly_summary
      
      expect(response).to redirect_to(huddles_path)
      expect(flash[:notice]).to eq('Weekly huddle summary posted to Slack successfully!')
    end

    it 'redirects with error message when job fails' do
      allow(Companies::WeeklyHuddlesReviewNotificationJob).to receive(:perform_and_get_result)
        .and_return({ success: false, error: 'Job failed' })
      
      post :post_weekly_summary
      
      expect(response).to redirect_to(huddles_path)
      expect(flash[:alert]).to eq('Failed to post weekly summary: Job failed')
    end
  end

  describe 'private methods' do
    describe '#get_weekly_summary_status' do
      let(:company) { create(:organization, :company) }
      let(:organization) { create(:organization, :team, parent: company) }

      it 'returns correct status when no recent summary exists' do
        controller.instance_variable_set(:@current_organization, organization)
        status = controller.send(:get_weekly_summary_status, organization)
        
        expect(status[:has_recent_summary]).to be false
        expect(status[:last_posted_at]).to be_nil
        expect(status[:slack_message_url]).to be_nil
      end

      it 'returns correct status when recent summary exists' do
        controller.instance_variable_set(:@current_organization, organization)
        
        # Create a recent weekly summary notification with required slack data
        notification = create(:notification, 
          notifiable: company,
          notification_type: 'huddle_summary',
          status: 'sent_successfully',
          created_at: 1.day.ago,
          message_id: '123456789.123456',
          metadata: { 'channel' => '#general' }
        )
        
        # Create slack configuration for the company
        slack_config = create(:slack_configuration, 
          organization: company,
          workspace_subdomain: 'testworkspace',
          workspace_url: 'https://testworkspace.slack.com'
        )
        
        status = controller.send(:get_weekly_summary_status, organization)
        
        expect(status[:has_recent_summary]).to be true
        expect(status[:last_posted_at]).to eq(notification.created_at)
        expect(status[:slack_message_url]).to be_present
      end
    end

    describe '#get_playbook_active_huddles' do
      let(:company) { create(:organization, :company) }
      let(:organization) { create(:organization, :team, parent: company) }
      let(:person) { create(:person) }

      before do
        controller.instance_variable_set(:@current_organization, organization)
        allow(controller).to receive(:current_person).and_return(person)
      end

      it 'returns empty hash when no active huddles exist' do
        playbook = create(:huddle_playbook, organization: organization)
        result = controller.send(:get_playbook_active_huddles, [playbook])
        expect(result).to eq({})
      end

      it 'returns active huddle data when huddle exists' do
        playbook = create(:huddle_playbook, organization: organization)
        # Create an active huddle for this week
        huddle = create(:huddle, 
          huddle_playbook: playbook, 
          started_at: Time.current.beginning_of_week(:monday) + 1.day,
          expires_at: 1.day.from_now
        )
        
        result = controller.send(:get_playbook_active_huddles, [playbook])
        
        expect(result[playbook.id]).to be_present
        expect(result[playbook.id][:huddle]).to eq(huddle)
        expect(result[playbook.id][:participant]).to be_nil
        expect(result[playbook.id][:has_feedback]).to be false
      end

      it 'includes participant information when user has joined' do
        playbook = create(:huddle_playbook, organization: organization)
        huddle = create(:huddle, 
          huddle_playbook: playbook, 
          started_at: Time.current.beginning_of_week(:monday) + 2.days,
          expires_at: 1.day.from_now
        )
        
        participant = create(:huddle_participant, huddle: huddle, person: person)
        
        result = controller.send(:get_playbook_active_huddles, [playbook])
        
        expect(result[playbook.id][:participant]).to eq(participant)
        expect(result[playbook.id][:has_feedback]).to be false
      end

      it 'includes feedback status when user has given feedback' do
        playbook = create(:huddle_playbook, organization: organization)
        huddle = create(:huddle, 
          huddle_playbook: playbook, 
          started_at: Time.current.beginning_of_week(:monday) + 3.days,
          expires_at: 1.day.from_now
        )
        
        participant = create(:huddle_participant, huddle: huddle, person: person)
        create(:huddle_feedback, huddle: huddle, person: person)
        
        result = controller.send(:get_playbook_active_huddles, [playbook])
        
        expect(result[playbook.id][:participant]).to eq(participant)
        expect(result[playbook.id][:has_feedback]).to be true
      end
    end

    describe '#get_slack_message_url' do
      let(:huddle) { create(:huddle) }

      it 'returns slack announcement url from huddle' do
        allow(huddle).to receive(:slack_announcement_url).and_return('https://slack.com/msg/123')
        
        result = controller.send(:get_slack_message_url, huddle)
        expect(result).to eq('https://slack.com/msg/123')
      end
    end
  end
end 