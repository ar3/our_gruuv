require 'rails_helper'

RSpec.describe 'Observation Wizard Basic Functionality', type: :request do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observer_teammate) { create(:teammate, person: observer, organization: company) }
  let(:observee1) { create(:teammate, organization: company) }
  let(:observee2) { create(:teammate, organization: company) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(observer)
    observer_teammate # Ensure observer teammate is created
  end

  describe 'Step 1: Basic observation creation' do
    it 'creates observation with basic data' do
      step1_params = {
        organization_id: company.id,
        observation: {
          story: 'Great work on the project!',
          primary_feeling: 'happy',
          secondary_feeling: 'proud',
          observed_at: Date.current,
          teammate_ids: [observee1.id.to_s, observee2.id.to_s]
        }
      }

      expect {
        post organization_observations_path(company), params: step1_params
      }.to change(Observation, :count).by(1)
       .and change(Observee, :count).by(2)

      observation = Observation.last
      expect(observation.story).to eq('Great work on the project!')
      expect(observation.primary_feeling).to eq('happy')
      expect(observation.secondary_feeling).to eq('proud')
      expect(observation.observees.count).to eq(2)
      expect(response).to redirect_to(organization_observation_path(company, observation))
    end
  end

  describe 'Step 2: Ratings and Privacy page' do
    it 'redirects to step 1 when no session data' do
      get set_ratings_organization_observation_path(company, 'new')
      
      expect(response).to redirect_to(new_organization_observation_path(company))
    end
  end

  describe 'Step 3: Review page' do
    it 'redirects to step 1 when no session data' do
      get review_organization_observation_path(company, 'new')
      
      expect(response).to redirect_to(new_organization_observation_path(company))
    end
  end

  describe 'Slack posting from show page' do
    let(:observation) do
      obs = build(:observation, observer: observer, company: company, story: 'Test story')
      obs.observees.build(teammate: observee1)
      obs.save!
      obs
    end

    it 'renders the show page with Slack posting form' do
      get organization_observation_path(company, observation)
      
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:show)
      expect(response.body).to include('Send Notifications')
    end

    it 'posts to Slack when requested' do
      slack_params = {
        organization_id: company.id,
        id: observation.id,
        notify_teammate_ids: [observee1.id.to_s]
      }

      expect(Observations::PostNotificationJob).to receive(:perform_later).with(observation.id, [observee1.id.to_s])
      
      post post_to_slack_organization_observation_path(company, observation), params: slack_params
      
      expect(response).to redirect_to(organization_observation_path(company, observation))
      expect(flash[:notice]).to include('Notifications sent successfully')
    end
  end
end
